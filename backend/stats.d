module backend.stats;
import std.stdio;

import defs;

void run(Instruction[] instructions) {
    ulong icount = instructions.length;
    ulong icount_call, icount_return, icount_jump,
          icount_data, icount_control, icount_other;
    foreach (inst; instructions) {
        switch (inst.opc.type) {
            case OpcodeType.Call:
                icount_call++;
            break;
            case OpcodeType.Return:
                icount_return++;
            break;
            case OpcodeType.Data:
                icount_data++;
            break;
            case OpcodeType.Jump:
                icount_jump++;
            break;
            case OpcodeType.Control:
                icount_control++;
            break;
            default:
                icount_other++;
            break;
        }
    }
    writeln("total instructions:\t",icount);
    writeln("instructions by type:");
    writeln("    call:          \t",icount_call);
    writeln("    return         \t",icount_return);
    writeln("    jump:          \t",icount_jump);
    writeln("    data:          \t",icount_data);
    writeln("    control:       \t",icount_control);
    writeln("    other:         \t",icount_other);
}
