enum RegClass {
    a, b, c, d, di, si, sp, bp, other, //real classes
    none, convert_to_i, convert_to_p, tmp_s //temporary classes
}
enum OpcodeType { Jump, Call, Return, Data, Control, Ignore, Warn }
enum OperandType { Constant, Register, Indirection, Unknown }

class ParseException : Exception {
    this(string msg) {
        super(msg);
    }
}
