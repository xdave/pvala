/* valaposixprofile.vala
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
 * 	Andrea Del Signore <sejerpz@gmail.com>
 */

using GLib;

/**
 * Factory function for the posix profile
 */
public class Vala.CodeGen.Posix {
	
	[CCode(cname="vala_codegenerator_factory")]
	public static Vala.CodeGenerator factory(Vala.CodeContext context,
						 string[] options) {
		context.add_define("POSIX");
		context.add_external_package("posix");
		context.add_external_package("posix-types");

		var codegen = new Vala.CodeGen.PosixSignalModule();
		codegen.trace_method_call = false;
		foreach (string option in options) {
			if (option == "trace-method-call") {
				codegen.trace_method_call = true;
			}
		}
		return codegen;
	}
}
