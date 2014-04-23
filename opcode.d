import std.stdio;
import std.conv;

import defs;

class OpcodeLoader {
    Opcode[string] opcodes;
    bool[string] prefix_list;
    this(File iset, bool warnings) {
        foreach (line; iset.byLine) {
            if (line.length == 0)
                continue;
            if (line[0] == ';')
                continue;
            auto opc = new Opcode;
            string[] fields = [""];
            foreach (ch; line) {
                if (ch == ' ' || ch == '\t')
                    fields ~= [""];
                else
                    fields[$-1] ~= ch;
            }
            if (fields.length == 0)
                continue;
            if (fields.length == 1) {
                warn("error loading iset: no type for ",fields[0], "; skipping");
                continue;
            }
            opc.name = fields[0];
            switch (fields[1]) {
                case "jump":
                    opc.type = OpcodeType.Jump;
                break;
                case "call":
                    opc.type = OpcodeType.Call;
                break;
                case "return":
                    opc.type = OpcodeType.Return;
                break;
                case "data":
                    opc.type = OpcodeType.Data;
                break;
                case "control":
                    opc.type = OpcodeType.Control;
                break;
                case "ignore":
                    opc.type = OpcodeType.Ignore;
                break;
                case "warn":
                    opc.type = OpcodeType.Warn;
                break;
                default:
                    goto case "ignore";
                break;
            }
            if (fields.length > 2) {
                foreach (f; fields[2..$]) {
                    if (f.length == 0)
                        continue;
                    if (f[0] == '+') {
                        if (f.length == 1) {
                            warn("error loading iset: unknown flag ",f," for ",fields[0],"; ignoring");
                        }
                        opc.extra_regs_out ~= classify_reg(f[1..$]);
                    } else if (f[0] == '-') {
                        if (f.length == 1) {
                            warn("error loading iset: unknown flag ",f," for ",fields[0],"; ignoring");
                        }
                        opc.extra_regs_in ~= classify_reg(f[1..$]);
                    } else {
                        switch (f) {
                            case "cond":
                                opc.flag_cond = true;
                            break;
                            case "mem":
                                opc.flag_mem = true;
                            break;
                            case "int":
                                opc.flag_int = true;
                            break;
                            case "prefix":
                                opc.flag_prefix = true;
                            break;
                            default:
                                warn("error loading iset: unknown flag ",f," for ",fields[0],"; ignoring");
                            break;
                        }
                    }
                }
            }
            if (fields[0] in opcodes) {
                warn("error loading iset: redundant instruction ",fields[0],"; skipping");
                continue;
            }
            opcodes[fields[0]] = opc;
        }
    }
}

Opcode unknown_opcode(string name) {
    Opcode unk = new Opcode;
    unk.name = name;
    unk.type = OpcodeType.Ignore;
    return unk;
}

RegClass classify_reg(string r) {
    switch (r) {
        case "a": return RegClass.a;
        case "b": return RegClass.b;
        case "c": return RegClass.c;
        case "d": return RegClass.d;
        case "si": return RegClass.si;
        case "di": return RegClass.di;
        case "sp": return RegClass.sp;
        case "bp": return RegClass.bp;
        default: return RegClass.other;
    }
}
