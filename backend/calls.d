module backend.calls;
import std.stdio;

import defs;

/* find the assembly-level call graph of the program
 *   this involves identifying functions
 *   by tracking the unique destination addresses of calls
 */


void run(Instruction[] instructions) {
    
    Function[ulong] fns;
    
    foreach (inst; instructions) {
        if (inst.opc.type == OpcodeType.Call) {
            writeln(inst);
        }
    }
}


private class Function {
    ulong address;
    ulong return_address;
    ulong[] calls;
}
