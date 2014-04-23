module backend.printer;
import std.stdio;

import defs;

void run(Instruction[] instructions, Section[] sections, bool[string] modes) {
    writeln("[begin instruction summary]");
    foreach (i,inst; instructions)
        writeln(i,"\t",inst);
    writeln("[end instruction summary]");
}
