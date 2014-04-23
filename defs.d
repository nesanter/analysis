import std.conv;

enum Backend { stats, printer, calls, cyclo, none }

enum RegClass {
    none,
    a, b, c, d, di, si, sp, bp, ip,       //real classes
    r8, r9, r10, r11, r12, r13, r14, r15, // ""
    seg, other,                           // ""
    convert_to_i, convert_to_p, tmp_s //temporary classes
}
enum OpcodeType { Jump, Call, Return, Data, Control, Ignore, Warn }
enum OperandType {
    Constant,
    Register,
    Indirection,
    IndirectRegister,
    Unknown 
}

class Section {
    ulong address;
    ulong begin, end;
    override string toString() {
		return "sec@"~to!string(address);
	}
}

class Instruction {
    Opcode opc;
    ulong address;
    Operand[] operands;
    Opcode[] prefix;
    string inst,raw;
    override string toString() {
        string s;
        if (prefix.length > 0) {
            s ~= "< ";
            foreach (pfx; prefix) {
                s ~= to!string(pfx)~" ";
            }
            s ~= "> ";
        }
        s ~= to!string(opc) ~ " :";
        foreach (op; operands) {
            s ~= " "~to!string(op);
        }
        //s ~= "@" ~ to!string(address);
        return s;
    }
}

class Operand {
    OperandType type;
    RegClass rc;
    ulong val;
    string raw;
    Operand[] subops;
    override string toString() {
        final switch (type) {
            case OperandType.Constant:
                return "$"~to!string(val);
            break;
            case OperandType.Indirection:
                if (subops.length == 0)
                    return "[]";
                string s = "["~to!string(subops[0]);
                if (subops.length > 1) {
                    foreach (op; subops[1..$]) {
                        s ~= ","~to!string(op);
                    }
                }
                return s~"]";
            break;
            case OperandType.Register:
                return "%"~to!string(rc);
            break;
            case OperandType.IndirectRegister:
                return "*"~to!string(rc);
            break;
            case OperandType.Unknown:
                return "?:"~raw;
            break;
        }
    }
}

class Opcode {
    string name;
    OpcodeType type;
    //flags
    bool flag_cond;
    bool flag_mem;
    bool flag_int;
    bool flag_prefix;
    RegClass[] extra_regs_out;
    RegClass[] extra_regs_in;
    
    override string toString() {
        string s = name ~ " (" ~ to!string(type) ~ ")";
        if (flag_cond)
            s ~= " cond";
        if (flag_mem)
            s ~= " mem";
        if (flag_int)
            s ~= " int";
        if (flag_prefix)
            s ~= " prefix";
        foreach (r; extra_regs_out) {
            s ~= " +" ~ to!string(r);
        }
        foreach (r; extra_regs_in) {
            s ~= " -" ~ to!string(r);
        }
        return s;
    }
}

class ParseException : Exception {
    this(string msg) {
        super(msg);
    }
}
class UnknownBackendException : Exception {
    string bad_backend;
    this(string msg, string bad) {
        bad_backend = bad;
        super(msg);
    }
}
class BackendException : Exception {
	this(string msg) {
		super(msg);
	}
}
