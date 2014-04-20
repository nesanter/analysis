enum RegClass {
    none,
    a, b, c, d, di, si, sp, bp,           //real classes
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

class ParseException : Exception {
    this(string msg) {
        super(msg);
    }
}
