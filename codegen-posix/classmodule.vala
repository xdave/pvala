/* posixclassmodule.vala
 *
 * Copyright (C) 2012  Andrea Del Signore
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 *  Andrea Del Signore <sejerpz@gmail.com>
 */

public class Vala.CodeGen.PosixClassModule : Vala.CodeGen.PosixDelegateModule {

	public override void generate_class_struct_declaration (Class cl, CCodeFile decl_space) {
		if (add_symbol_declaration (decl_space, cl, "struct _" + get_ccode_name (cl))) {
			return;
		}

		if (cl.base_class != null && cl.base_class != object_type) {
			// base class declaration
			generate_class_struct_declaration (cl.base_class, decl_space);
		}
		foreach (DataType base_type in cl.get_base_types ()) {
			var iface = base_type.data_type as Interface;
			if (iface != null) {
				generate_interface_declaration (iface, decl_space);
			}
		}

		generate_class_declaration (cl, decl_space);

		bool is_gtypeinstance = !cl.is_compact;
		bool is_fundamental = cl.base_class == null;
		bool has_private_struct = cl.has_private_fields;
		string class_name = "%sClass".printf (get_ccode_name (cl));
		var instance_struct = new CCodeStruct ("_%s".printf (get_ccode_name (cl)));
		var type_struct = new CCodeStruct ("_" + class_name);

		if (cl.base_class != null) {
			instance_struct.add_field (get_ccode_name (cl.base_class), "parent_instance");
		} else if (is_fundamental) {
			instance_struct.add_field ("Object", "parent_instance");
		}

		if (cl.is_compact && cl.base_class == null && cl.get_fields ().size == 0) {
			// add dummy member, C doesn't allow empty structs
			instance_struct.add_field ("int", "dummy");
		}

		decl_space.add_type_declaration (new CCodeTypeDefinition ("struct %sPrivate".printf (instance_struct.name), new CCodeVariableDeclarator ("%sPrivate".printf (get_ccode_name (cl)))));

		if (has_private_struct) {
			instance_struct.add_field ("%sPrivate *".printf (get_ccode_name (cl)), "priv");
		}
		if (is_fundamental) {
			//type_struct.add_field ("size_t", "size");
			//type_struct.add_field ("void", "(*finalize) (%s *self)".printf (get_ccode_name (cl)));
			type_struct.add_field ("Type", "parent_class");
		} else {
			if (cl.base_class == object_type) {
				type_struct.add_field ("Type", "parent_class");
			} else {
				type_struct.add_field ("%sClass".printf (get_ccode_name (cl.base_class)), "parent_class");
			}
		}

		foreach (DataType base_type in cl.get_base_types ()) {
			if (base_type.data_type is Interface) {
				type_struct.add_field ("%s".printf (get_ccode_name (base_type.data_type)), get_ccode_lower_case_name (base_type.data_type, null));
			}
		}

		foreach (Method m in cl.get_methods ()) {
			generate_virtual_method_declaration (m, decl_space, type_struct);
		}

		foreach (Signal sig in cl.get_signals ()) {
			instance_struct.add_field ("SignalHandler *", sig.name);
			if (sig.default_handler != null) {
				generate_virtual_method_declaration (sig.default_handler, decl_space, type_struct);
			}
		}

		foreach (Property prop in cl.get_properties ()) {
			if (!prop.is_abstract && !prop.is_virtual) {
				continue;
			}
			generate_type_declaration (prop.property_type, decl_space);

			var t = (ObjectTypeSymbol) prop.parent_symbol;

			var this_type = new ObjectType (t);
			var cselfparam = new CCodeParameter ("self", get_ccode_name (this_type));

			if (prop.get_accessor != null) {
				var vdeclarator = new CCodeFunctionDeclarator ("get_%s".printf (prop.name));
				vdeclarator.add_parameter (cselfparam);
				string creturn_type;
				if (prop.property_type.is_real_non_null_struct_type ()) {
					var cvalueparam = new CCodeParameter ("result", get_ccode_name (prop.get_accessor.value_type) + "*");
					vdeclarator.add_parameter (cvalueparam);
					creturn_type = "void";
				} else {
					creturn_type = get_ccode_name (prop.get_accessor.value_type);
				}

				var array_type = prop.property_type as ArrayType;
				if (array_type != null) {
					for (int dim = 1; dim <= array_type.rank; dim++) {
						vdeclarator.add_parameter (new CCodeParameter (get_array_length_cname ("result", dim), "int*"));
					}
				} else if ((prop.property_type is DelegateType) && ((DelegateType) prop.property_type).delegate_symbol.has_target) {
					vdeclarator.add_parameter (new CCodeParameter (get_delegate_target_cname ("result"), "void**"));
				}

				var vdecl = new CCodeDeclaration (creturn_type);
				vdecl.add_declarator (vdeclarator);
				type_struct.add_declaration (vdecl);
			}
			if (prop.set_accessor != null) {
				CCodeParameter cvalueparam;
				if (prop.property_type.is_real_non_null_struct_type ()) {
					cvalueparam = new CCodeParameter ("value", get_ccode_name (prop.set_accessor.value_type) + "*");
				} else {
					cvalueparam = new CCodeParameter ("value", get_ccode_name (prop.set_accessor.value_type));
				}

				var vdeclarator = new CCodeFunctionDeclarator ("set_%s".printf (prop.name));
				vdeclarator.add_parameter (cselfparam);
				vdeclarator.add_parameter (cvalueparam);

				var array_type = prop.property_type as ArrayType;
				if (array_type != null) {
					for (int dim = 1; dim <= array_type.rank; dim++) {
						vdeclarator.add_parameter (new CCodeParameter (get_array_length_cname ("value", dim), "int"));
					}
				} else if ((prop.property_type is DelegateType) && ((DelegateType) prop.property_type).delegate_symbol.has_target) {
					vdeclarator.add_parameter (new CCodeParameter (get_delegate_target_cname ("value"), "void*"));
				}

				var vdecl = new CCodeDeclaration ("void");
				vdecl.add_declarator (vdeclarator);
				type_struct.add_declaration (vdecl);
			}
		}

		foreach (Field f in cl.get_fields ()) {
			string field_ctype = get_ccode_name (f.variable_type);
			if (f.is_volatile) {
				field_ctype = "volatile " + field_ctype;
			}

			if (f.access != SymbolAccessibility.PRIVATE) {
				if (f.binding == MemberBinding.INSTANCE) {
					generate_type_declaration (f.variable_type, decl_space);

					instance_struct.add_field (field_ctype, get_ccode_name (f), get_ccode_declarator_suffix (f.variable_type));
					if (f.variable_type is ArrayType && get_ccode_array_length (f)) {
						// create fields to store array dimensions
						var array_type = (ArrayType) f.variable_type;

						if (!array_type.fixed_length) {
							var len_type = int_type.copy ();

							for (int dim = 1; dim <= array_type.rank; dim++) {
								string length_cname;
								if (get_ccode_array_length_name (f) != null) {
									length_cname = get_ccode_array_length_name (f);
								} else {
									length_cname = get_array_length_cname (f.name, dim);
								}
								instance_struct.add_field (get_ccode_name (len_type), length_cname);
							}

							if (array_type.rank == 1 && f.is_internal_symbol ()) {
								instance_struct.add_field (get_ccode_name (len_type), get_array_size_cname (f.name));
							}
						}
					} else if (f.variable_type is DelegateType) {
						var delegate_type = (DelegateType) f.variable_type;
						if (delegate_type.delegate_symbol.has_target) {
							// create field to store delegate target
							instance_struct.add_field ("void*", get_ccode_delegate_target_name (f));
							if (delegate_type.value_owned) {
								instance_struct.add_field ("DestroyNotify", get_delegate_target_destroy_notify_cname (f.name));
							}
						}
					}
				} else if (f.binding == MemberBinding.CLASS) {
					type_struct.add_field (field_ctype, get_ccode_name (f));
				}
			}
		}

		/* Add to source */
		if (!cl.is_compact || cl.base_class == null) {
			// derived compact classes do not have a struct
			decl_space.add_type_definition (instance_struct);
		}

		if (is_gtypeinstance) {
			decl_space.add_type_definition (type_struct);
		}

		decl_space.add_type_declaration (new CCodeTypeDefinition ("struct _%sClass".printf (get_ccode_name (cl)), new CCodeVariableDeclarator ("%sClass".printf (get_ccode_name (cl)))));
		decl_space.add_type_declaration (new CCodeTypeDefinition ("struct _%s".printf (get_ccode_name (cl)), new CCodeVariableDeclarator ("%s".printf (get_ccode_name (cl)))));
		decl_space.add_type_member_declaration (new CCodeMacroReplacement ("%s_GET_TYPE(o)".printf (get_ccode_upper_case_name (cl, null)), "((%sClass *) ((Object *)o)->type)".printf (get_ccode_name (cl))));
	}

	public override void visit_class (Class cl) {
		push_context (new EmitContext (cl));
		push_line (cl.source_reference);

		var old_param_spec_struct = param_spec_struct;
		var old_prop_enum = prop_enum;
		var old_class_init_context = class_init_context;
		var old_base_init_context = base_init_context;
		var old_class_finalize_context = class_finalize_context;
		var old_base_finalize_context = base_finalize_context;
		var old_instance_init_context = instance_init_context;
		var old_instance_finalize_context = instance_finalize_context;
		var old_get_interface_context = get_interface_context;

		if (get_ccode_name (cl).length < 3) {
			cl.error = true;
			Report.error (cl.source_reference, "Class name `%s' is too short".printf (get_ccode_name (cl)));
			return;
		}

		if (cl.base_class == null && !cl.is_compact) {
			// HACK: this should be done by the parser and NOT here!
			// every class inherith from Object
			cl.base_class = object_type;
		}

		bool is_fundamental = cl.base_class == null;
		bool has_interfaces = false;

		foreach (DataType base_type in cl.get_base_types ()) {
			if (base_type.data_type is Interface) {
				has_interfaces = true;
				break;
			}
		}
		cfile.add_include ("stdlib.h");

		//prop_enum = new CCodeEnum ();
		//prop_enum.add_value (new CCodeEnumValue ("%s_DUMMY_PROPERTY".printf (get_ccode_upper_case_name (cl, null))));
		class_init_context = new EmitContext (cl);
		base_init_context = new EmitContext (cl);
		class_finalize_context = new EmitContext (cl);
		base_finalize_context = new EmitContext (cl);
		instance_init_context = new EmitContext (cl);
		instance_finalize_context = new EmitContext (cl);
		get_interface_context = new EmitContext (cl);

		generate_class_struct_declaration (cl, cfile);
		generate_class_private_declaration (cl, cfile);

		if (!cl.is_internal_symbol ()) {
			generate_class_struct_declaration (cl, header_file);
		}
		if (!cl.is_private_symbol ()) {
			generate_class_struct_declaration (cl, internal_header_file);
		}


		begin_base_init_function (cl);
		begin_class_init_function (cl);
		begin_instance_init_function (cl);

		begin_base_finalize_function (cl);
		begin_class_finalize_function (cl);
		begin_finalize_function (cl);

		if (cl.base_class == null) {
			begin_instance_init_function (cl);
			begin_finalize_function (cl);
		}

		if (has_interfaces) {
			begin_get_interface_function (cl);
		}

		cl.accept_children (this);

		if (cl.class_constructor != null || cl.has_class_private_fields) {
			add_base_init_function (cl);
		}
		add_class_init_function (cl);

		if (cl.class_destructor != null || cl.has_class_private_fields) {
			add_base_finalize_function (cl);
		}

		if (cl.static_destructor != null) {
			add_class_finalize_function (cl);
		}

		add_instance_init_function (cl);

		if (!cl.is_compact && (cl.get_fields ().size > 0 || cl.destructor != null || cl.is_fundamental ())) {
			add_finalize_function (cl);
		}

		if (cl.comment != null) {
			cfile.add_type_member_definition (new CCodeComment (cl.comment.content));
		}

		if (has_interfaces) {
			add_get_interface_function (cl);
		}

		/* Type declaration & initialization */
		var type_var_decl = new CCodeVariableDeclarator ("%s_type".printf(get_ccode_lower_case_name(cl)));
		type_var_decl.initializer = new CCodeConstant("NULL"); // new CCodeFunctionCall (new CCodeIdentifier ("%s_type_init".printf(get_ccode_lower_case_name(cl))));

		var type_decl = new CCodeDeclaration ("%sClass *".printf (get_ccode_name (cl)));
		type_decl.add_declarator (type_var_decl);

		if (cl.access == SymbolAccessibility.PRIVATE) {
			type_decl.modifiers = CCodeModifiers.STATIC;
		} else {
			type_decl.modifiers = CCodeModifiers.EXTERN;
		}
		cfile.add_type_declaration (type_decl);


		if (is_fundamental) {
			//var ref_count = new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "ref_count");

			 //ref function
			var ref_fun = new CCodeFunction (get_ccode_lower_case_prefix (cl) + "ref", get_ccode_name (cl) + "*");
			ref_fun.add_parameter (new CCodeParameter ("self", get_ccode_name (cl) + "*"));
			if (cl.access == SymbolAccessibility.PRIVATE) {
				ref_fun.modifiers = CCodeModifiers.STATIC;
			}
			push_function (ref_fun);
			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("object_ref"));
			ccall.add_argument (new CCodeIdentifier ("self"));
			ccode.add_expression (ccall);
			ccode.add_return (new CCodeIdentifier ("self"));
			pop_function ();
			/*
			//ccode.add_declaration (get_ccode_name (cl) + "*", new CCodeVariableDeclarator ("self", new CCodeIdentifier ("instance")));
			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("os_atomic_int_inc"));
			ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, ref_count));
			ccode.add_expression (ccall);
			ccode.add_return (new CCodeIdentifier ("self"));

			pop_function ();
			*/
			cfile.add_function (ref_fun);

			// unref function
			var unref_fun = new CCodeFunction (get_ccode_lower_case_prefix (cl) + "unref", "void");
			unref_fun.add_parameter (new CCodeParameter ("self", get_ccode_name (cl) + "*"));
			if (cl.access == SymbolAccessibility.PRIVATE) {
				unref_fun.modifiers = CCodeModifiers.STATIC;
			}
			push_function (unref_fun);
			ccall = new CCodeFunctionCall (new CCodeIdentifier ("object_unref"));
			ccall.add_argument (new CCodeIdentifier ("self"));
			ccode.add_expression (ccall);
			pop_function ();

			/*
			//ccode.add_declaration (get_ccode_name (cl) + "*", new CCodeVariableDeclarator ("self", new CCodeIdentifier ("instance")));
			ccall = new CCodeFunctionCall (new CCodeIdentifier ("os_atomic_int_dec_and_test"));
			ccall.add_argument (new CCodeUnaryExpression (CCodeUnaryOperator.ADDRESS_OF, ref_count));
			ccode.open_if (ccall);

			var get_class = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_CLASS".printf (get_ccode_upper_case_name (cl, null))));
			get_class.add_argument (new CCodeIdentifier ("self"));

			// finalize class
			//var ccast = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_CLASS".printf (get_ccode_upper_case_name (cl, null))));
			//ccast.add_argument (new CCodeIdentifier ("self"));
			ccall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (new CCodeMemberAccess.pointer(new CCodeIdentifier ("self"), "class"), "finalize"));
			ccall.add_argument (new CCodeIdentifier ("self"));
			ccode.add_expression (ccall);

			// free type instance
			var free = new CCodeFunctionCall (new CCodeIdentifier ("free"));
			free.add_argument (new CCodeIdentifier ("self"));
			//free.add_argument (new CCodeCastExpression (new CCodeIdentifier ("self"), get_ccode_name (cl) + "*"));
			ccode.add_expression (free);

			ccode.close ();
			pop_function ();
			*/

			cfile.add_function (unref_fun);

		}


		if (cl.is_compact && cl.base_class == null) {
			// derived compact classes do not have fields
			add_instance_init_function (cl);
			add_finalize_function (cl);
		}

		param_spec_struct = old_param_spec_struct;
		prop_enum = old_prop_enum;
		class_init_context = old_class_init_context;
		base_init_context = old_base_init_context;
		class_finalize_context = old_class_finalize_context;
		base_finalize_context = old_base_finalize_context;
		instance_init_context = old_instance_init_context;
		instance_finalize_context = old_instance_finalize_context;
		get_interface_context = old_get_interface_context;

		pop_line ();
		pop_context ();
	}

	public virtual void generate_virtual_method_declaration (Method m, CCodeFile decl_space, CCodeStruct type_struct) {
		if (!m.is_abstract && !m.is_virtual) {
			return;
		}

		var creturn_type = m.return_type;
		if (m.return_type.is_real_non_null_struct_type ()) {
			// structs are returned via out parameter
			creturn_type = new VoidType ();
		}

		// add vfunc field to the type struct
		var vdeclarator = new CCodeFunctionDeclarator (get_ccode_vfunc_name (m));
		var cparam_map = new HashMap<int,CCodeParameter> (direct_hash, direct_equal);

		generate_cparameters (m, decl_space, cparam_map, new CCodeFunction ("fake"), vdeclarator);

		var vdecl = new CCodeDeclaration (get_ccode_name (creturn_type));
		vdecl.add_declarator (vdeclarator);
		type_struct.add_declaration (vdecl);
	}

	void generate_class_private_declaration (Class cl, CCodeFile decl_space) {
		if (decl_space.add_declaration (get_ccode_name (cl) + "Private")) {
			return;
		}

		bool has_class_locks = false;

		var instance_priv_struct = new CCodeStruct ("_%sPrivate".printf (get_ccode_name (cl)));
		var type_priv_struct = new CCodeStruct ("_%sClassPrivate".printf (get_ccode_name (cl)));

		foreach (Field f in cl.get_fields ()) {
			string field_ctype = get_ccode_name (f.variable_type);
			if (f.is_volatile) {
				field_ctype = "volatile " + field_ctype;
			}

			if (f.binding == MemberBinding.INSTANCE) {
				if (f.access == SymbolAccessibility.PRIVATE)  {
					generate_type_declaration (f.variable_type, decl_space);

					instance_priv_struct.add_field (field_ctype, get_ccode_name (f), get_ccode_declarator_suffix (f.variable_type));
					if (f.variable_type is ArrayType && get_ccode_array_length (f)) {
						// create fields to store array dimensions
						var array_type = (ArrayType) f.variable_type;
						var len_type = int_type.copy ();

						if (!array_type.fixed_length) {
							for (int dim = 1; dim <= array_type.rank; dim++) {
								string length_cname;
								if (get_ccode_array_length_name (f) != null) {
									length_cname = get_ccode_array_length_name (f);
								} else {
									length_cname = get_array_length_cname (f.name, dim);
								}
								instance_priv_struct.add_field (get_ccode_name (len_type), length_cname);
							}

							if (array_type.rank == 1 && f.is_internal_symbol ()) {
								instance_priv_struct.add_field (get_ccode_name (len_type), get_array_size_cname (f.name));
							}
						}
					} else if (f.variable_type is DelegateType) {
						var delegate_type = (DelegateType) f.variable_type;
						if (delegate_type.delegate_symbol.has_target) {
							// create field to store delegate target
							instance_priv_struct.add_field ("void*", get_ccode_delegate_target_name (f));
							if (delegate_type.value_owned) {
								instance_priv_struct.add_field ("DestroyNotify", get_delegate_target_destroy_notify_cname (f.name));
							}
						}
					}
				}

				if (f.get_lock_used ()) {
					cl.has_private_fields = true;
					// add field for mutex
					instance_priv_struct.add_field (get_ccode_name (mutex_type), get_symbol_lock_name (f.name));
				}
			} else if (f.binding == MemberBinding.CLASS) {
				if (f.access == SymbolAccessibility.PRIVATE) {
					type_priv_struct.add_field (field_ctype, get_ccode_name (f));
				}

				if (f.get_lock_used ()) {
					has_class_locks = true;
					// add field for mutex
					type_priv_struct.add_field (get_ccode_name (mutex_type), get_symbol_lock_name (get_ccode_name (f)));
				}
			}
		}


		foreach (Property prop in cl.get_properties ()) {
			if (prop.binding == MemberBinding.INSTANCE) {
				if (prop.get_lock_used ()) {
					cl.has_private_fields = true;
					// add field for mutex
					instance_priv_struct.add_field (get_ccode_name (mutex_type), get_symbol_lock_name (prop.name));
				}
			} else if (prop.binding == MemberBinding.CLASS) {
				if (prop.get_lock_used ()) {
					has_class_locks = true;
					// add field for mutex
					type_priv_struct.add_field (get_ccode_name (mutex_type), get_symbol_lock_name (prop.name));
				}
			}
		}

		if (cl.has_class_private_fields || has_class_locks) {
			decl_space.add_type_declaration (new CCodeTypeDefinition ("struct %s".printf (type_priv_struct.name), new CCodeVariableDeclarator ("%sClassPrivate".printf (get_ccode_name (cl)))));
			if (!context.require_glib_version (2, 24)) {
				var cdecl = new CCodeDeclaration ("GQuark");
				cdecl.add_declarator (new CCodeVariableDeclarator ("_vala_%s_class_private_quark".printf (get_ccode_lower_case_name (cl)), new CCodeConstant ("0")));
				cdecl.modifiers = CCodeModifiers.STATIC;
				decl_space.add_type_declaration (cdecl);
			}
		}

		/* only add the *Private struct if it is not empty, i.e. we actually have private data */
		if (cl.has_private_fields || cl.get_type_parameters ().size > 0) {
			decl_space.add_type_definition (instance_priv_struct);
			//var macro = "(G_TYPE_INSTANCE_GET_PRIVATE ((o), %s, %sPrivate))".printf (get_ccode_type_id (cl), get_ccode_name (cl));
			var macro = "((%s *(o))->priv)".printf (get_ccode_name (cl));
			decl_space.add_type_member_declaration (new CCodeMacroReplacement ("%s_GET_PRIVATE(o)".printf (get_ccode_upper_case_name (cl, null)), macro));
		}

		/*
		if (cl.has_class_private_fields || has_class_locks) {
			decl_space.add_type_member_declaration (type_priv_struct);

			string macro;
			if (context.require_glib_version (2, 24)) {
				macro = "(G_TYPE_CLASS_GET_PRIVATE (klass, %s, %sClassPrivate))".printf (get_ccode_type_id (cl), get_ccode_name (cl));
			} else {
				macro = "((%sClassPrivate *) g_type_get_qdata (G_TYPE_FROM_CLASS (klass), _vala_%s_class_private_quark))".printf (get_ccode_name (cl), get_ccode_lower_case_name (cl));
			}
			decl_space.add_type_member_declaration (new CCodeMacroReplacement ("%s_GET_CLASS_PRIVATE(klass)".printf (get_ccode_upper_case_name (cl, null)), macro));
		}

		decl_space.add_type_member_declaration (prop_enum);
		*/
	}

	private void begin_base_init_function (Class cl) {
		push_context (base_init_context);

		header_file.add_include ("stddef.h");

		var base_init = new CCodeFunction ("%s_base_init".printf (get_ccode_lower_case_name (cl, null)), "void");
		base_init.add_parameter (new CCodeParameter ("klass", "%sClass *".printf (get_ccode_name (cl))));
		base_init.modifiers = CCodeModifiers.STATIC;

		push_function (base_init);

		if (cl.has_class_private_fields) {
			ccode.add_declaration ("%sClassPrivate *".printf (get_ccode_name (cl)), new CCodeVariableDeclarator ("priv"));
			ccode.add_declaration ("%sClassPrivate *".printf (get_ccode_name (cl)), new CCodeVariableDeclarator ("parent_priv", new CCodeConstant ("NULL")));
			ccode.add_declaration ("GType", new CCodeVariableDeclarator ("parent_type"));

			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_type_parent"));
			var ccall2 = new CCodeFunctionCall (new CCodeIdentifier ("G_TYPE_FROM_CLASS"));
			ccall2.add_argument (new CCodeIdentifier ("klass"));
			ccall.add_argument (ccall2);
			ccode.add_assignment (new CCodeIdentifier ("parent_type"), ccall);

			ccode.open_if (new CCodeIdentifier ("parent_type"));
			ccall = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_CLASS_PRIVATE".printf (get_ccode_upper_case_name (cl, null))));
			ccall2 = new CCodeFunctionCall (new CCodeIdentifier ("g_type_class_peek"));
			ccall2.add_argument (new CCodeIdentifier ("parent_type"));
			ccall.add_argument (ccall2);
			ccode.add_assignment (new CCodeIdentifier ("parent_priv"), ccall);
			ccode.close ();

			ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_slice_new0"));
			ccall.add_argument (new CCodeIdentifier ("%sClassPrivate".printf(get_ccode_name (cl))));
			ccode.add_assignment (new CCodeIdentifier ("priv"), ccall);

			cfile.add_include ("string.h");

			ccode.open_if (new CCodeIdentifier ("parent_priv"));
			ccall = new CCodeFunctionCall (new CCodeIdentifier ("memcpy"));
			ccall.add_argument (new CCodeIdentifier ("priv"));
			ccall.add_argument (new CCodeIdentifier ("parent_priv"));
			ccall.add_argument (new CCodeIdentifier ("sizeof (%sClassPrivate)".printf(get_ccode_name (cl))));
			ccode.add_expression (ccall);
			ccode.close ();

			ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_type_set_qdata"));
			ccall2 = new CCodeFunctionCall (new CCodeIdentifier ("G_TYPE_FROM_CLASS"));
			ccall2.add_argument (new CCodeIdentifier ("klass"));
			ccall.add_argument (ccall2);
			ccall.add_argument (new CCodeIdentifier ("_vala_%s_class_private_quark".printf (get_ccode_lower_case_name (cl))));
			ccall.add_argument (new CCodeIdentifier ("priv"));
			ccode.add_expression (ccall);
		}

		pop_context ();
	}

	private void add_base_init_function (Class cl) {
		cfile.add_function (base_init_context.ccode);
	}

	public virtual void generate_class_init (Class cl) {

	}

	private void begin_class_init_function (Class cl) {
		push_context (class_init_context);

		var func = new CCodeFunction ("%s_type_init".printf (get_ccode_lower_case_name (cl, null)));
		//func.add_parameter (new CCodeParameter ("klass", "%sClass *".printf (get_ccode_name (cl))));
		//func.modifiers = CCodeModifiers.STATIC;

		CCodeFunctionCall ccall;

		/* save pointer to parent class
		var parent_decl = new CCodeDeclaration ("void *");
		var parent_var_decl = new CCodeVariableDeclarator ("%s_parent_class".printf (get_ccode_lower_case_name (cl, null)));
		parent_var_decl.initializer = new CCodeConstant ("NULL");
		parent_decl.add_declarator (parent_var_decl);
		parent_decl.modifiers = CCodeModifiers.STATIC;
		cfile.add_type_member_declaration (parent_decl);
		*/

		push_function (func);

		if (trace_method_call) {
			ccode.add_expression (trace_method_enter ("%s.type_init".printf (cl.get_full_name ())));
		}

		var type_init = new CCodeBlock ();
		var var_type_name = "%s_type".printf(get_ccode_lower_case_name(cl));
		var id = new CCodeIdentifier (var_type_name);
		var zero = new CCodeConstant ("NULL");
		var condition = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, id, zero);
		ccode.add_statement (new CCodeIfStatement (condition, type_init));

		var bc = cl.base_class;
		while (bc != null && bc != object_type) {
			var type_var_decl = new CCodeVariableDeclarator ("%s_type".printf(get_ccode_lower_case_name(bc)));
			var decl = new CCodeDeclaration ("%sClass *".printf(get_ccode_name (bc)));
			decl.add_declarator (type_var_decl);
			decl.modifiers = CCodeModifiers.EXTERN;
			cfile.add_type_declaration (decl);
			bc = bc.base_class;
		}

		if (cl.base_class == null) {
			ccall = new CCodeFunctionCall (new CCodeIdentifier ("object_type_init"));
			type_init.add_statement (new CCodeExpressionStatement (ccall));
		} else {
			// call type init of the base class
			ccall = new CCodeFunctionCall (new CCodeIdentifier ("%s_type_init".printf (get_ccode_lower_case_name (cl.base_class, null))));
			type_init.add_statement (new CCodeExpressionStatement (ccall));
		}
		ccall = new CCodeFunctionCall (new CCodeIdentifier ("calloc"));
		ccall.add_argument (new CCodeConstant("1"));
		ccall.add_argument (new CCodeIdentifier ("sizeof (%sClass)".printf (get_ccode_name (cl))));
		type_init.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeIdentifier(var_type_name), new CCodeCastExpression (ccall, "%sClass *".printf(get_ccode_name (cl))))));

		string base_type_name;
		if (cl.base_class == null) {
			var parent_assignment = new CCodeAssignment (new CCodeMemberAccess.pointer (new CCodeIdentifier (var_type_name), "parent_class"),
				new CCodeUnaryExpression(CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier("object_type")));
			type_init.add_statement (new CCodeExpressionStatement (parent_assignment));
			base_type_name = "object_type";
		} else {
			var parent_assignment = new CCodeAssignment (new CCodeMemberAccess.pointer (new CCodeIdentifier (var_type_name), "parent_class"),
				new CCodeUnaryExpression(CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier("%s_type".printf(get_ccode_lower_case_name (cl.base_class, null)))));
			type_init.add_statement (new CCodeExpressionStatement (parent_assignment));
			base_type_name = "%s_type".printf (get_ccode_lower_case_name (cl.base_class));
		}

		CCodeAssignment base_type_assignment = new CCodeAssignment (
			new CCodeMemberAccess.pointer (new CCodeCastExpression(new CCodeIdentifier (var_type_name), "Type *"), "base_type"),
			new CCodeCastExpression (new CCodeIdentifier (base_type_name), "Type *"));
		type_init.add_statement (new CCodeExpressionStatement (base_type_assignment));

		if (cl.get_fields ().size > 0 || cl.destructor != null || cl.is_fundamental ()) {
			// set finalize function
			var fundamental_class = cl;
			while (fundamental_class.base_class != null) {
				fundamental_class = fundamental_class.base_class;
			}

			CCodeExpression maccess = new CCodeCastExpression(new CCodeIdentifier (var_type_name), "Type *");
			CCodeAssignment finalize_assignment = new CCodeAssignment (new CCodeMemberAccess.pointer (maccess, "finalize"),new CCodeCastExpression (new CCodeIdentifier (get_ccode_lower_case_prefix (cl) + "finalize"), "void (*)(void*)"));
			type_init.add_statement (new CCodeExpressionStatement (finalize_assignment));
		}

		bool get_interface_added = false;
		foreach (DataType base_type in cl.get_base_types ()) {
			var iface = base_type.data_type as Interface;
			if (iface != null) {
				if (!get_interface_added) {
					CCodeExpression maccess = new CCodeCastExpression(new CCodeIdentifier (var_type_name), "Type *");
					CCodeAssignment get_interface_assignment = new CCodeAssignment (
						new CCodeMemberAccess.pointer (maccess, "get_interface"),
						new CCodeCastExpression (new CCodeIdentifier (get_ccode_lower_case_prefix (cl) + "get_interface"), "void * (*) (void *, void *)"));
					type_init.add_statement (new CCodeExpressionStatement (get_interface_assignment));
					get_interface_added = true;
				}

				ccall = new CCodeFunctionCall (new CCodeIdentifier ("%s_base_init".printf (get_ccode_lower_case_name (iface, null))));
				type_init.add_statement (new CCodeExpressionStatement (ccall));
				var assignment = new CCodeAssignment (new CCodeMemberAccess.pointer (new CCodeIdentifier (var_type_name), get_ccode_lower_case_name (iface, null)),
					new CCodeUnaryExpression(CCodeUnaryOperator.POINTER_INDIRECTION, new CCodeIdentifier("%s_type".printf(get_ccode_lower_case_name (iface, null)))));
				type_init.add_statement (new CCodeExpressionStatement (assignment));
			}
		}

		/* add struct for private fields
		if (cl.has_private_fields || cl.get_type_parameters ().size > 0) {
			ccall = new CCodeFunctionCall (new CCodeIdentifier ("g_type_class_add_private"));
			ccall.add_argument (new CCodeIdentifier (var_type_name));
			ccall.add_argument (new CCodeConstant ("sizeof (%sPrivate)".printf (get_ccode_name (cl))));
			ccode.add_expression (ccall);
		}*/

		/* connect overridden methods */
		var base_class = cl;
		while (base_class.base_class != null && base_class.base_class != object_type) {
			base_class = base_class.base_class;
		}

		foreach (Method m in cl.get_methods ()) {
			Method base_method;
			CCodeMemberAccess maccess;

			if (m.base_method != null) {
				CCodeExpression type;
				base_method = m.base_method;
				if (cl.base_class == null) {
					type = new CCodeIdentifier (var_type_name);
				} else {
					type = new CCodeCastExpression(new CCodeIdentifier (var_type_name), "%sClass *".printf(get_ccode_name (base_class)));
				}
				maccess = new CCodeMemberAccess.pointer (type, get_ccode_vfunc_name (base_method));
			} else if (m.base_interface_method != null) {
				base_method = m.base_interface_method;
				maccess = new CCodeMemberAccess (new CCodeMemberAccess.pointer (new CCodeIdentifier (var_type_name), get_ccode_lower_case_name (m.base_interface_method.parent_symbol, null)), get_ccode_vfunc_name (base_method));
			} else {
				continue;
			}

			// there is currently no default handler for abstract async methods
			if (!m.is_abstract || !m.coroutine) {
				type_init.add_statement (new CCodeExpressionStatement (new CCodeAssignment (maccess, new CCodeIdentifier (get_ccode_real_name (m)))));
				if (m.coroutine) {
					type_init.add_statement (new CCodeExpressionStatement (new CCodeAssignment (maccess, new CCodeIdentifier (get_ccode_finish_real_name (m)))));
				}
			}
		}

		/* connect default signal handlers */
		foreach (Signal sig in cl.get_signals ()) {
			if (sig.default_handler == null) {
				continue;
			}
			var ccast = new CCodeFunctionCall (new CCodeIdentifier ("%s_type".printf (get_ccode_name (cl))));
			ccast.add_argument (new CCodeIdentifier (var_type_name));
			type_init.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeMemberAccess.pointer (ccast, get_ccode_vfunc_name (sig.default_handler)), new CCodeIdentifier (get_ccode_real_name (sig.default_handler)))));
		}

		/* connect overridden properties */
		foreach (Property prop in cl.get_properties ()) {
			if (prop.base_property == null) {
				continue;
			}
			var base_type = prop.base_property.parent_symbol;

			var ccast = new CCodeFunctionCall (new CCodeIdentifier ("%s_type".printf (get_ccode_name (base_type))));
			ccast.add_argument (new CCodeIdentifier (var_type_name));

			if (!get_ccode_no_accessor_method (prop.base_property)) {
				if (prop.get_accessor != null) {
					string cname = CCodeBaseModule.get_ccode_real_name (prop.get_accessor);
					type_init.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeMemberAccess.pointer (ccast, "get_%s".printf (prop.name)), new CCodeIdentifier (cname))));
				}
				if (prop.set_accessor != null) {
					string cname = CCodeBaseModule.get_ccode_real_name (prop.set_accessor);
					type_init.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeMemberAccess.pointer (ccast, "set_%s".printf (prop.name)), new CCodeIdentifier (cname))));
				}
			}
		}

		generate_class_init (cl);

		/* create signals */
		foreach (Signal sig in cl.get_signals ()) {
			var signal_creation = get_signal_creation (sig, cl);
			if (((CCodeIdentifier)signal_creation.call).name == "")
				continue;

			if (sig.comment != null) {
				ccode.add_statement (new CCodeComment (sig.comment.content));
			}
			type_init.add_statement (new CCodeExpressionStatement (signal_creation));
		}

		if (trace_method_call) {
			ccode.add_expression (trace_method_leave ("%s.type_init".printf (cl.get_full_name ())));
		}
		pop_context ();
	}

	private void add_class_init_function (Class cl) {
		cfile.add_function_declaration (class_init_context.ccode);
		cfile.add_function (class_init_context.ccode);
	}

	private void begin_instance_init_function (Class cl) {
		push_context (instance_init_context);

		var func = new CCodeFunction ("%s_instance_init".printf (get_ccode_lower_case_name (cl, null)));
		func.add_parameter (new CCodeParameter ("self", "%s *".printf (get_ccode_name (cl))));
		//func.modifiers = CCodeModifiers.STATIC;

		push_function (func);

		if (trace_method_call) {
			ccode.add_expression (trace_method_enter ("%s.instance_init".printf (cl.get_full_name ())));
		}
		// Add declaration, since the instance_init function is explicitly called
		// by the creation methods
		cfile.add_function_declaration (func);

		string base_init_funcname;
		string cast_type_name;
		CCodeFunctionCall ccall;

		if (cl.base_class == object_type) {
			// object_construct doesn't exist
			base_init_funcname = "object_instance_init";
			cast_type_name = "void *";

			ccall = new CCodeFunctionCall(new CCodeIdentifier (base_init_funcname));
			ccall.add_argument (new CCodeCastExpression(new CCodeIdentifier("self"), cast_type_name));
			ccode.add_expression(ccall);
		}
		if (cl.has_private_fields || cl.get_type_parameters ().size > 0) {
			//var ccall = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_PRIVATE".printf (get_ccode_upper_case_name (cl, null))));
			//ccall.add_argument (new CCodeIdentifier ("self"));
			//func.add_assignment (new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv"), ccall);
			ccall = new CCodeFunctionCall (new CCodeIdentifier ("calloc"));
			ccall.add_argument (new CCodeConstant("1"));
			ccall.add_argument (new CCodeIdentifier ("sizeof (%sPrivate)".printf (get_ccode_name (cl))));
			ccode.add_assignment (new CCodeMemberAccess.pointer (new CCodeIdentifier ("self"), "priv"), new CCodeCastExpression (ccall, "%sPrivate".printf(get_ccode_name (cl)) + "*"));
		}

		pop_context ();
	}

	private void add_instance_init_function (Class cl) {
		if (trace_method_call) {
			instance_init_context.ccode.add_expression (trace_method_leave ("%s.instance_init".printf (cl.get_full_name ())));
		}
		cfile.add_function (instance_init_context.ccode);
	}

	private void begin_class_finalize_function (Class cl) {
		push_context (class_finalize_context);

		var function = new CCodeFunction ("%s_class_finalize".printf (get_ccode_lower_case_name (cl, null)), "void");
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeParameter ("klass", get_ccode_name (cl) + "Class *"));

		push_function (function);
		if (trace_method_call) {
			ccode.add_expression (trace_method_enter ("%s.class_finalize".printf (cl.get_full_name ())));
		}
		if (cl.static_destructor != null) {
			cl.static_destructor.body.emit (this);
		}


		pop_context ();
	}

	private void add_class_finalize_function (Class cl) {
		if (trace_method_call) {
			class_finalize_context.ccode.add_expression (trace_method_leave ("%s.class_finalize".printf (cl.get_full_name ())));
		}
		cfile.add_function_declaration (class_finalize_context.ccode);
		cfile.add_function (class_finalize_context.ccode);
	}

	private void begin_base_finalize_function (Class cl) {
		push_context (base_finalize_context);

		var function = new CCodeFunction ("%s_base_finalize".printf (get_ccode_lower_case_name (cl, null)), "void");
		function.modifiers = CCodeModifiers.STATIC;

		function.add_parameter (new CCodeParameter ("klass", get_ccode_name (cl) + "Class *"));

		push_function (function);
		if (trace_method_call) {
			ccode.add_expression (trace_method_enter ("%s.base_finalize".printf (cl.get_full_name ())));
		}
		if (cl.class_destructor != null) {
			cl.class_destructor.body.emit (this);
		}

		pop_context ();
	}

	private void add_base_finalize_function (Class cl) {
		push_context (base_finalize_context);

		if (cl.has_class_private_fields) {
			ccode.open_block ();

			var cdecl = new CCodeDeclaration ("%sClassPrivate *".printf (get_ccode_name (cl)));
			cdecl.add_declarator (new CCodeVariableDeclarator ("priv"));
			ccode.add_statement (cdecl);

			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("%s_GET_CLASS_PRIVATE".printf (get_ccode_upper_case_name (cl, null))));
			ccall.add_argument (new CCodeConstant ("klass"));
			ccode.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeIdentifier ("priv"), ccall)));

			ccall = new CCodeFunctionCall (new CCodeIdentifier ("free"));
			ccall.add_argument (new CCodeIdentifier ("%sClassPrivate".printf (get_ccode_name (cl))));
			ccall.add_argument (new CCodeIdentifier ("priv"));
			ccode.add_statement (new CCodeExpressionStatement (ccall));

			ccode.close ();
		}

		if (trace_method_call) {
			ccode.add_expression (trace_method_leave ("%s.finalize".printf (cl.get_full_name ())));
		}
		cfile.add_function_declaration (ccode);
		cfile.add_function (ccode);

		pop_context ();
	}

	private void begin_finalize_function (Class cl) {
		push_context (instance_finalize_context);

		if (!cl.is_compact) {
			var func = new CCodeFunction ("%s_finalize".printf (get_ccode_lower_case_name (cl, null)));
			func.add_parameter (new CCodeParameter ("self", get_ccode_name (cl) + "*"));
			func.modifiers = CCodeModifiers.STATIC;

			push_function (func);

			//CCodeFunctionCall ccall = generate_instance_cast (new CCodeIdentifier ("obj"), cl);

			//ccode.add_declaration ("%s *".printf (get_ccode_name (cl)), new CCodeVariableDeclarator ("self"));
			//ccode.add_assignment (new CCodeIdentifier ("self"), ccall);
		} else {
			var function = new CCodeFunction (get_ccode_lower_case_prefix (cl) + "free", "void");
			if (cl.access == SymbolAccessibility.PRIVATE) {
				function.modifiers = CCodeModifiers.STATIC;
			}

			function.add_parameter (new CCodeParameter ("self", get_ccode_name (cl) + "*"));

			push_function (function);
		}

		if (trace_method_call) {
			ccode.add_expression (trace_method_enter ("%s.finalize".printf (cl.get_full_name ())));
		}
		if (cl.destructor != null) {
			cl.destructor.body.emit (this);

			if (current_method_inner_error) {
				ccode.add_declaration ("GError *", new CCodeVariableDeclarator.zero ("_inner_error_", new CCodeConstant ("NULL")));
			}

			if (current_method_return) {
				// support return statements in destructors
				ccode.add_label ("_return");
			}
		}

		pop_context ();
	}

	private void add_finalize_function (Class cl) {
		if (!cl.is_compact) {
			var fundamental_class = cl;
			while (fundamental_class.base_class != null) {
				fundamental_class = fundamental_class.base_class;
			}

			// chain up to finalize function of the base class
			string base_name;

			if (cl.base_class == null) {
				base_name = "object";
			} else {
				base_name = get_ccode_lower_case_name (cl.base_class);
			}
			var ccast = new CCodeCastExpression (new CCodeIdentifier ("%s_type".printf(base_name)), "Type *");
			var ccall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (ccast, "finalize"));
			ccall.add_argument (new CCodeIdentifier ("self"));
			push_context (instance_finalize_context);
			ccode.add_expression (ccall);

			if (cl.has_private_fields) {
				// free private struct
				var free = new CCodeFunctionCall (new CCodeIdentifier ("free"));
				free.add_argument (new CCodeMemberAccess.pointer(new CCodeIdentifier ("self"), "priv"));
				ccode.add_expression (free);
			}
			pop_context ();

			cfile.add_function_declaration (instance_finalize_context.ccode);
		} else {
			var ccall = new CCodeFunctionCall (new CCodeIdentifier ("free"));
			ccall.add_argument (new CCodeIdentifier (get_ccode_name (cl)));
			ccall.add_argument (new CCodeIdentifier ("self"));
			push_context (instance_finalize_context);
			ccode.add_expression (ccall);

			pop_context ();
		}

		if (trace_method_call) {
			instance_finalize_context.ccode.add_expression (trace_method_leave ("%s.finalize".printf (cl.get_full_name ())));
		}
		cfile.add_function (instance_finalize_context.ccode);
	}

	private void begin_get_interface_function (Class cl) {
		push_context (get_interface_context);

		var function = new CCodeFunction ("%s_get_interface".printf (get_ccode_lower_case_name (cl, null)), "void *");
		function.modifiers = CCodeModifiers.STATIC;
		function.add_parameter (new CCodeParameter ("self", get_ccode_name (cl) + " *"));
		function.add_parameter (new CCodeParameter ("interface_type", "void *"));

		push_function (function);
		if (trace_method_call) {
			function.add_expression (trace_method_enter ("%s.get_interface".printf (cl.get_full_name ())));
		}
		function.add_declaration ("void *", new CCodeVariableDeclarator("interface", new CCodeIdentifier("NULL")));

		bool first = true;
		foreach (DataType base_type in cl.get_base_types ()) {
			if (base_type.data_type is Interface) {
				var interface_name = get_ccode_lower_case_name(base_type.data_type, null);
				if (first) {
					function.open_if (new CCodeBinaryExpression(CCodeBinaryOperator.EQUALITY, new CCodeIdentifier("interface_type"), new CCodeIdentifier("%s_type".printf (interface_name))));
				} else {
					function.else_if (new CCodeBinaryExpression(CCodeBinaryOperator.EQUALITY, new CCodeIdentifier("interface_type"), new CCodeIdentifier("%s_type".printf (interface_name))));
				}
				function.add_assignment (new CCodeIdentifier("interface"),
					new CCodeUnaryExpression(CCodeUnaryOperator.ADDRESS_OF, new CCodeMemberAccess.pointer(
						new CCodeCastExpression(new CCodeParenthesizedExpression(
							new CCodeMemberAccess.pointer(new CCodeCastExpression(new CCodeIdentifier("self"), "Object *"), "type")), "%sClass *".printf (get_ccode_name (cl))),
						interface_name)));
				if (first)
					first = false;
			}
		}
		function.add_else ();
		string base_name;
		if (cl.base_class == null) {
			base_name = "object";
		} else {
			base_name = get_ccode_lower_case_name (cl.base_class, null);
		}
		var ccall = new CCodeFunctionCall (new CCodeMemberAccess.pointer (new CCodeCastExpression(new CCodeIdentifier("%s_type".printf(base_name)), "Type *"), "get_interface"));
		ccall.add_argument (new CCodeIdentifier("self"));
		ccall.add_argument (new CCodeIdentifier("interface_type"));
		function.add_assignment (new CCodeIdentifier("interface"), ccall);
		function.close ();

		if (trace_method_call) {
			function.add_expression (trace_method_leave ("%s.get_interface".printf (cl.get_full_name ())));
		}
		function.add_return (new CCodeIdentifier("interface"));
		pop_context ();
	}

	private void add_get_interface_function (Class cl) {
		push_context (get_interface_context);

		cfile.add_function_declaration (ccode);
		cfile.add_function (ccode);

		pop_context ();
	}

	public override void visit_base_access (BaseAccess expr) {
		CCodeExpression this_access;
		if (is_in_coroutine ()) {
			// use closure
			this_access = new CCodeMemberAccess.pointer (new CCodeIdentifier ("_data_"), "self");
		} else {
			this_access = new CCodeIdentifier ("self");
		}

		set_cvalue (expr, new CCodeCastExpression(this_access, "%s *".printf(get_ccode_name (expr.value_type.data_type))));
	}

	public override void generate_interface_declaration (Interface iface, CCodeFile decl_space) {
		if (add_symbol_declaration (decl_space, iface, get_ccode_name (iface))) {
			return;
		}

		foreach (DataType prerequisite in iface.get_prerequisites ()) {
			var prereq_cl = prerequisite.data_type as Class;
			var prereq_iface = prerequisite.data_type as Interface;
			if (prereq_cl != null) {
				generate_class_declaration (prereq_cl, decl_space);
			} else if (prereq_iface != null) {
				generate_interface_declaration (prereq_iface, decl_space);
			}
		}

		var type_struct = new CCodeStruct ("_%s".printf (get_ccode_name (iface)));
		var macro = "((%s *)(((Object*)obj)->type->get_interface(obj, %s_type)))".printf (get_ccode_name (iface), get_ccode_lower_case_name (iface, null));
		decl_space.add_type_declaration (new CCodeMacroReplacement ("%s_GET_INTERFACE(obj)".printf (get_ccode_upper_case_name (iface, null)), macro));
		decl_space.add_type_declaration (new CCodeNewline ());

		foreach (Method m in iface.get_methods ()) {
			generate_virtual_method_declaration (m, decl_space, type_struct);
		}

		foreach (Signal sig in iface.get_signals ()) {
			if (sig.default_handler != null) {
				generate_virtual_method_declaration (sig.default_handler, decl_space, type_struct);
			}
		}

		foreach (Property prop in iface.get_properties ()) {
			if (!prop.is_abstract && !prop.is_virtual) {
				continue;
			}
			generate_type_declaration (prop.property_type, decl_space);

			var t = (ObjectTypeSymbol) prop.parent_symbol;

			bool returns_real_struct = prop.property_type.is_real_non_null_struct_type ();

			var this_type = new ObjectType (t);
			var cselfparam = new CCodeParameter ("self", get_ccode_name (this_type));

			if (prop.get_accessor != null) {
				var vdeclarator = new CCodeFunctionDeclarator ("get_%s".printf (prop.name));
				vdeclarator.add_parameter (cselfparam);
				string creturn_type;
				if (returns_real_struct) {
					var cvalueparam = new CCodeParameter ("value", get_ccode_name (prop.get_accessor.value_type) + "*");
					vdeclarator.add_parameter (cvalueparam);
					creturn_type = "void";
				} else {
					creturn_type = get_ccode_name (prop.get_accessor.value_type);
				}

				var array_type = prop.property_type as ArrayType;
				if (array_type != null) {
					for (int dim = 1; dim <= array_type.rank; dim++) {
						vdeclarator.add_parameter (new CCodeParameter (get_array_length_cname ("result", dim), "int*"));
					}
				}

				var vdecl = new CCodeDeclaration (creturn_type);
				vdecl.add_declarator (vdeclarator);
				type_struct.add_declaration (vdecl);
			}
			if (prop.set_accessor != null) {
				var vdeclarator = new CCodeFunctionDeclarator ("set_%s".printf (prop.name));
				vdeclarator.add_parameter (cselfparam);
				if (returns_real_struct) {
					var cvalueparam = new CCodeParameter ("value", get_ccode_name (prop.set_accessor.value_type) + "*");
					vdeclarator.add_parameter (cvalueparam);
				} else {
					var cvalueparam = new CCodeParameter ("value", get_ccode_name (prop.set_accessor.value_type));
					vdeclarator.add_parameter (cvalueparam);
				}

				var array_type = prop.property_type as ArrayType;
				if (array_type != null) {
					for (int dim = 1; dim <= array_type.rank; dim++) {
						vdeclarator.add_parameter (new CCodeParameter (get_array_length_cname ("value", dim), "int"));
					}
				}

				var vdecl = new CCodeDeclaration ("void");
				vdecl.add_declarator (vdeclarator);
				type_struct.add_declaration (vdecl);
			}
		}

		decl_space.add_type_declaration (new CCodeTypeDefinition ("struct _%s".printf (get_ccode_name (iface)), new CCodeVariableDeclarator ("%s".printf (get_ccode_name (iface)))));
		decl_space.add_type_definition (type_struct);
	}

	public override void visit_interface (Interface iface) {
		push_context (new EmitContext (iface));
		push_line (iface.source_reference);

		if (get_ccode_name (iface).length < 3) {
			iface.error = true;
			Report.error (iface.source_reference, "Interface name `%s' is too short".printf (get_ccode_name (iface)));
			return;
		}

		generate_interface_declaration (iface, cfile);
		if (!iface.is_internal_symbol ()) {
			generate_interface_declaration (iface, header_file);
		}
		if (!iface.is_private_symbol ()) {
			generate_interface_declaration (iface, internal_header_file);
		}

		iface.accept_children (this);

		add_interface_base_init_function (iface);

		if (iface.comment != null) {
			cfile.add_type_member_definition (new CCodeComment (iface.comment.content));
		}

		/* Type declaration & initialization */
		var type_var_decl = new CCodeVariableDeclarator ("%s_type".printf(get_ccode_lower_case_name(iface)));
		type_var_decl.initializer = new CCodeConstant("NULL"); // new CCodeFunctionCall (new CCodeIdentifier ("%s_type_init".printf(get_ccode_lower_case_name(cl))));

		var type_decl = new CCodeDeclaration ("%s *".printf (get_ccode_name (iface)));
		type_decl.add_declarator (type_var_decl);

		if (iface.access == SymbolAccessibility.PRIVATE) {
			type_decl.modifiers = CCodeModifiers.STATIC;
		} else {
			type_decl.modifiers = CCodeModifiers.EXTERN;
		}
		cfile.add_type_declaration (type_decl);

		pop_line ();
		pop_context ();
	}

	private void add_interface_base_init_function (Interface iface) {
		push_context (new EmitContext (iface));

		var var_type_name = "%s_type".printf(get_ccode_lower_case_name(iface));
		var base_init = new CCodeFunction ("%s_base_init".printf (get_ccode_lower_case_name (iface, null)), "void");

		push_function (base_init);

		var type_init = new CCodeBlock ();
		var id = new CCodeIdentifier (var_type_name);
		var zero = new CCodeConstant ("NULL");
		var condition = new CCodeBinaryExpression (CCodeBinaryOperator.EQUALITY, id, zero);
		ccode.add_statement (new CCodeIfStatement (condition, type_init));

		var ccall = new CCodeFunctionCall (new CCodeIdentifier ("calloc"));
		ccall.add_argument (new CCodeConstant("1"));
		ccall.add_argument (new CCodeIdentifier ("sizeof (%s)".printf (get_ccode_name (iface))));
		type_init.add_statement (new CCodeExpressionStatement (new CCodeAssignment (new CCodeIdentifier(var_type_name), new CCodeCastExpression (ccall, "%s *".printf(get_ccode_name (iface))))));

		var ciface = new CCodeIdentifier ("iface");

		/* connect default signal handlers */
		foreach (Signal sig in iface.get_signals ()) {
			if (sig.default_handler == null) {
				continue;
			}
			var cname = get_ccode_real_name (sig.default_handler);
			type_init.add_statement (new CCodeAssignment(new CCodeMemberAccess.pointer (ciface, get_ccode_vfunc_name (sig.default_handler)), new CCodeIdentifier (cname)));
		}

		/* create signals */
		foreach (Signal sig in iface.get_signals ()) {
			var signal_creation = get_signal_creation (sig, iface);
			if (((CCodeIdentifier)signal_creation.call).name == "")
				continue;

			if (sig.comment != null) {
				type_init.add_statement (new CCodeComment (sig.comment.content));
			}
			type_init.add_statement (signal_creation);
		}

		// connect default implementations
		foreach (Method m in iface.get_methods ()) {
			if (m.is_virtual) {
				var cname = get_ccode_real_name (m);
				type_init.add_statement (new CCodeAssignment (new CCodeMemberAccess.pointer (ciface, get_ccode_vfunc_name (m)), new CCodeIdentifier (cname)));
				if (m.coroutine) {
					type_init.add_statement (new CCodeAssignment (new CCodeMemberAccess.pointer (ciface, get_ccode_finish_vfunc_name (m)), new CCodeIdentifier (get_ccode_finish_real_name (m))));
				}
			}
		}

		//ccode.close ();

		pop_function ();
		pop_context ();
		cfile.add_function_declaration (base_init);
		header_file.add_function_declaration (base_init);
		cfile.add_function (base_init);
	}
}
