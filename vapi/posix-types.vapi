/* posix-types.vapi
 *
 * Copyright (C) 2008-2009  Jürg Billeter
 * Copyright (C) 2010 Marco Trevisan (Treviño)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 * 	Jürg Billeter <j@bitron.ch>
 *  Marco Trevisan (Treviño) <mail@3v1n0.net>
 */
 
 /*
  * From the original posix.vapi file
  */
  
#if POSIX
[CCode (cname = "bool", cheader_filename = "stdbool.h", default_value = "false", marshaller_type_name = "BOOLEAN", get_value_function = "bool")]
[BooleanType]
public struct bool {
	public inline unowned string to_string () {
		if (this) {
			return "true";
		} else {
			return "false";
		}
	}

	public static inline bool parse (string str) {
		if (str == "true") {
			return true;
		} else {
			return false;
		}
	}
}

[CCode (cname = "char", default_value = "\'\\0\'", marshaller_type_name = "CHAR", get_value_function = "char")]
[IntegerType (rank = 2, min = 0, max = 127)]
public struct char {
	public inline string to_string () {
		return "%c".printf (this);
	}
}

[CCode (cname = "unsigned char", default_value = "\'\\0\'", marshaller_type_name = "UCHAR", get_value_function = "char")]
[IntegerType (rank = 3, min = 0, max = 255)]
public struct uchar {
	public inline string to_string () {
		return "%hhu".printf (this);
	}
}

[CCode (cname = "int", default_value = "0", marshaller_type_name = "INT", get_value_function = "int")]
[IntegerType (rank = 6)]
public struct int {
	public inline string to_string () {
		return "%d".printf (this);
	}

	[CCode (cname = "atoi", cheader_filename = "stdlib.h")]
	public static int parse (string str);
}

[CCode (cname = "unsigned int", default_value = "0U", marshaller_type_name = "UINT", get_value_function = "unsigned int")]
[IntegerType (rank = 7)]
public struct uint {
	public inline string to_string () {
		return "%u".printf (this);
	}
}

[CCode (cname = "short", default_value = "0")]
[IntegerType (rank = 4, min = -32768, max = 32767)]
public struct short {
	public inline string to_string () {
		return "%hi".printf (this);
	}
}

[CCode (cname = "unsigned short", default_value = "0U")]
[IntegerType (rank = 5, min = 0, max = 65535)]
public struct ushort {
	public inline string to_string () {
		return "%hu".printf (this);
	}
}

[CCode (cname = "long", default_value = "0L", marshaller_type_name = "LONG", get_value_function = "long")]
[IntegerType (rank = 8)]
public struct long {
	public inline string to_string () {
		return "%li".printf (this);
	}

	[CCode (cname = "atol", cheader_filename = "stdlib.h")]
	public static long parse (string str);
}

[CCode (cname = "unsigned long", default_value = "0UL", marshaller_type_name = "LONG", get_value_function = "unsigned long")]
[IntegerType (rank = 9)]
public struct ulong {
	public inline string to_string () {
		return "%lu".printf (this);
	}
}

[CCode (cname = "size_t", cheader_filename = "sys/types.h", default_value = "0UL")]
[IntegerType (rank = 9)]
public struct size_t {
	public inline string to_string () {
		return "%zu".printf (this);
	}
}

[CCode (cname = "ssize_t", cheader_filename = "sys/types.h", default_value = "0L")]
[IntegerType (rank = 8)]
public struct ssize_t {
	public inline string to_string () {
		return "%zi".printf (this);
	}
}

[CCode (cname = "int8_t", cheader_filename = "stdint.h", default_value = "0")]
[IntegerType (rank = 1, min = -128, max = 127)]
public struct int8 {
	[CCode (cname = "PRIi8", cheader_filename = "inttypes.h")]
	public const string FORMAT;

	public inline string to_string () {
		return ("%" + FORMAT).printf (this);
	}
}

[CCode (cname = "uint8_t", cheader_filename = "stdint.h", default_value = "0U")]
[IntegerType (rank = 3, min = 0, max = 255)]
public struct uint8 {
	[CCode (cname = "PRIu8", cheader_filename = "inttypes.h")]
	public const string FORMAT;

	public inline string to_string () {
		return ("%" + FORMAT).printf (this);
	}
}

[CCode (cname = "int16_t", cheader_filename = "stdint.h", default_value = "0")]
[IntegerType (rank = 4, min = -32768, max = 32767)]
public struct int16 {
	[CCode (cname = "PRIi16", cheader_filename = "inttypes.h")]
	public const string FORMAT;

	public inline string to_string () {
		return ("%" + FORMAT).printf (this);
	}
}

[CCode (cname = "uint16_t", cheader_filename = "stdint.h", default_value = "0U")]
[IntegerType (rank = 5, min = 0, max = 65535)]
public struct uint16 {
	[CCode (cname = "PRIu16", cheader_filename = "inttypes.h")]
	public const string FORMAT;

	public inline string to_string () {
		return ("%" + FORMAT).printf (this);
	}
}

[CCode (cname = "int32_t", cheader_filename = "stdint.h", default_value = "0")]
[IntegerType (rank = 6)]
public struct int32 {
	[CCode (cname = "PRIi32", cheader_filename = "inttypes.h")]
	public const string FORMAT;

	public inline string to_string () {
		return ("%" + FORMAT).printf (this);
	}
}

[CCode (cname = "uint32_t", cheader_filename = "stdint.h", default_value = "0U")]
[IntegerType (rank = 7)]
public struct uint32 {
	[CCode (cname = "PRIu32", cheader_filename = "inttypes.h")]
	public const string FORMAT;

	public inline string to_string () {
		return ("%" + FORMAT).printf (this);
	}
}

[CCode (cname = "int64_t", cheader_filename = "stdint.h", default_value = "0LL")]
[IntegerType (rank = 10)]
public struct int64 {
	[CCode (cname = "PRIi64", cheader_filename = "inttypes.h")]
	public const string FORMAT;

	public inline string to_string () {
		return ("%" + FORMAT).printf (this);
	}

	[CCode (cname = "strtoll", cheader_filename = "stdlib.h")]
	public static int64 parse (string str, out unowned string? end = null, int base = 10);
}

[CCode (cname = "uint64_t", cheader_filename = "stdint.h", default_value = "0ULL")]
[IntegerType (rank = 11)]
public struct uint64 {
	[CCode (cname = "PRIu64", cheader_filename = "inttypes.h")]
	public const string FORMAT;

	public inline string to_string () {
		return ("%" + FORMAT).printf (this);
	}

	[CCode (cname = "strtoull", cheader_filename = "stdlib.h")]
	public static uint64 parse (string str, out unowned string? end = null, int base = 10);
}

[CCode (cname = "float", default_value = "0.0F", marshaller_type_name = "FLOAT", get_value_function = "float")]
[FloatingType (rank = 1)]
public struct float {
	public inline string to_string () {
		return "%.8g".printf (this);
	}
}

[CCode (cname = "double", default_value = "0.0", marshaller_type_name = "DOUBLE", get_value_function = "double")]
[FloatingType (rank = 2)]
public struct double {
	public inline string to_string () {
		return "%.17g".printf (this);
	}

	[CCode (cname = "strtod", cheader_filename = "stdlib.h")]
	public static double parse (string str, out unowned string? end = null);
}

[CCode (cheader_filename = "time.h")]
[IntegerType (rank = 8)]
public struct time_t {
	[CCode (cname = "time")]
	public time_t ();
}


[Compact]
[Immutable]
[GIR (name = "utf8")]
[CCode (cname = "char", const_cname = "const char", copy_function = "strdup", free_function = "free", cheader_filename = "stdlib.h,string.h,stdarg.h", type_id = "TYPE_STRING", marshaller_type_name = "STRING", param_spec_function = "g_param_spec_string", get_value_function = "char *", set_value_function = "g_value_set_string", take_value_function = "g_value_take_string", type_signature = "s")]
public class string {
	[Deprecated (replacement = "int.parse")]
	[CCode (cname="atoi")]
	public int to_int();
	[Deprecated (replacement = "long.parse")]
	[CCode (cname="atol")]
	public long to_long();
	[Deprecated (replacement = "int64.parse")]
	[CCode (cname="atoll")]
	public int64 to_int64();
	[Deprecated (replacement = "string.length")]
	[CCode (cname="strlen")]
	public int len();

	[CCode (cname="strncmp")]
	public int strncmp(string str2, int len);

	[PrintfFormat]
	public string printf (...);

	[CCode (cname="vsprintf")]
	private static int _vsprintf (string buf, string format, va_list var_args);

	[CCode (cname="vsnprintf")]
	private static int _vsnprintf (string? buf, int len, string format,  va_list var_args);

	public string substring (long offset, long len = -1) {
		long string_length = this.length;

		if (offset < 0) {
			offset = string_length + offset;
		}
		if (len < 0) {
			len = string_length - offset;
		}

		string buf = (string)(new char[len + 1]);
		return Posix.strncpy (buf, (string*)((char*) this + offset), len);
	}

	public string vsprintf (va_list var_args) {
		int len = _vsnprintf (null, 0, this, var_args);
		string buf = (string)(new char[len+1]);

		_vsprintf (buf, this, var_args);
		return buf;
	}

	public inline unowned string to_string () {
		return this;
	}

	public int length {
		[CCode (cname = "strlen")]
		get;
	}

	public bool has_prefix (string prefix) {
		return this.strncmp(prefix, prefix.length) == 0;
	}

	public int index_of (string needle, int start_index = 0) {
		char* result = Posix.strstr ((string*) ((char*) this + start_index), needle);

		if (result != null) {
			return (int) (result - (char*) this);
		} else {
			return -1;
		}
	}

	/* strrstr: not available on all systems
	public int last_index_of (string needle, int start_index = 0) {
		char* result = Posix.strrstr ((char*) this + start_index, (char*) needle);

		if (result != null) {
			return (int) (result - (char*) this);
		} else {
			return -1;
		}
	}*/

	public int index_of_char (char c, int start_index = 0) {
		char* result = Posix.strchr ((string *) ((char*) this + start_index), (int) c);

		if (result != null) {
			return (int) (result - (char*) this);
		} else {
			return -1;
		}
	}

	public int last_index_of_char (char c, int start_index = 0) {
		char* result = Posix.strrchr ((string *) ((char*) this + start_index), (int) c);

		if (result != null) {
			return (int) (result - (char*) this);
		} else {
			return -1;
		}
	}
}

[SimpleType]
[CCode (cheader_filename="stdarg.h", cprefix="va_", has_type_id = false, destroy_function = "va_end", lvalue_access = false)]
public struct va_list {
	[CCode (cname = "va_start")]
	public va_list ();
	[CCode (cname = "va_copy")]
	public va_list.copy (va_list src);
	[CCode (generic_type_pos = 1.1)]
	public unowned G arg<G> ();
}

[CCode (ref_function = "object_ref", unref_function = "object_unref", marshaller_type_name = "OBJECT")]
public class Object {
	public uint ref_count;
}


[ErrorBase]
public class Error {
	public Error ();
	public string message;
}
#endif
