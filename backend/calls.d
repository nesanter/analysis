module backend.calls;
import std.stdio;

import defs;

/* find the assembly-level call graph of the program
 *   this involves identifying functions
 *   by tracking the unique destination addresses of calls
 */


void run(Instruction[] instructions, Section[] sections, bool[string] modes) {
	Function[Section] fns;
	
    foreach (sec; sections) {
		if (sec !in fns)
			fns[sec] = new Function;
		foreach (inst; instructions[sec.begin..sec.end]) {
			if (inst.opc.type == OpcodeType.Call) {
				if (inst.operands[0].type == OperandType.Constant) {
					Section dest = identify_section(inst.operands[0].val, sections);
					if (dest is null) {
						writeln("dest is null");
						fns[sec].unknown_edges++;
					} else {
						if (dest in fns[sec].edges)
							fns[sec].edges[dest]++;
						else
							fns[sec].edges[dest] = 1;
					}
				} else {
					fns[sec].unknown_edges++;
				}
			}
		}
	}
	
	foreach (sec; fns.byKey) {
		writeln(sec," -> ",fns[sec].edges," + ",fns[sec].unknown_edges);
	}
}

Section identify_section(ulong address, Section[] sections) {
	foreach (i; 0 .. sections.length-1) {
		if (sections[i].address <= address && sections[i+1].address > address)
			return sections[i];
	}
	return sections[$-1];
}

private class Function {
    Section node;
    ulong[Section] edges;
    ulong unknown_edges;
}
