module backend.calls;
import std.stdio;

import defs;

/* find the assembly-level call graph of the program
 *   this involves identifying functions
 *   by tracking the unique destination addresses of calls
 */
 
 
/*  notes on modified strahler number algorithm
 *    s(n):
 *      if s(n) defined for each child:
 *        find max (m) and number of children with max (j)
 *        if j >= 2:
 *          return m + 1
 *        else
 *          return m
 *      else if no children:
 *        return 1
 *      else
 *        for each child c:
 *          s(c)
 *          goto start
 *   note:
 *     if bidirectional link from parent to self:
 *       calculate w/o recursing into parent
 *       and mark as "unstable"
 * 
 *     if another parent references an unstable n:
 *       recalculate s(n)
 *       
 * 
 */

void run(Instruction[] instructions, Section[] sections, bool[string] modes) {
	
	Function[Section] fns;
	Function f;
    
    //writeln(sections.length);
    //return;
    
    foreach (sec; sections) {
        //writeln(sec);
		if (sec !in fns) {
			fns[sec] = new Function;
            fns[sec].node = sec;
        }
        f = fns[sec];
		foreach (inst; instructions[sec.begin..sec.end]) {
			if (inst.opc.type == OpcodeType.Call) {
				if (inst.operands[0].type == OperandType.Constant) {
					Section dest = identify_section(inst.operands[0].val, sections);
					if (dest is null) {
						warn("dest is null");
						fns[sec].unknown_edges++;
					} else {
                        Function f2;
                        if (dest !in fns) {
                            f2 = new Function;
                            f2.node = dest;
                            fns[dest] = f2;
                        } else {
                            f2 = fns[dest];
                        }
						if (f2 in f.edges)
							f.edges[f2]++;
						else
							f.edges[f2] = 1;
					}
				} else {
					f.unknown_edges++;
				}
			}
		}
	}
    
    //writeln("here");
    
    //determine strahler number
    ulong max_strahler;
    int i;
    Function msfn;
    //while (1) {}
    foreach (fn; fns.byValue) {
        //writeln(fn,fn.node,fn.edges);
        //writeln(&fn.strahler);
        ulong s = fn.strahler(null, i++);
        if (s > max_strahler) {
            max_strahler = s;
            msfn = fn;
        }
        //foreach (fn2; fns.byValue)
        //    fn2.reset();
    }
    msfn.strahler(null, 0);
    
    bool trimdot;
    if ("trim" in modes)
        trimdot = modes["trim"];
    
	if ("dot" in modes && modes["dot"]) {
		writeln("digraph calls {");
		foreach (fn; fns.byValue) {
            if (trimdot && fn.s <= 2)
                continue;
            writeln("s",fn.node.address,"[label=\"",fn.s,"\"]");
            if (fn.edges.length > 0) {
                write("s",fn.node.address," -> { ");
                foreach (edge; fn.edges.byKey) {
                    if (trimdot && edge.s <= 2)
                        continue;
                    write("s",edge.node.address," ");
                }
                writeln("}");
            }
		}
		writeln("}");
	} else {
        
        writeln("strahler number\t",max_strahler);
	}
}

private Section identify_section(ulong address, Section[] sections) {
	foreach (i; 0 .. sections.length-1) {
		if (sections[i].address <= address && sections[i+1].address > address)
			return sections[i];
	}
	return sections[$-1];
}

private class Function {
    Section node;
    ulong[Function] edges;
    ulong unknown_edges;
    ulong s, id;
    bool unstable, active;
    /*
    void strahler(int id) {
        if (visited == id) return;
        visited = id;
        if (edges.length == 0) {
            rank = 1;
            return;
        }
        ulong max, count;
        foreach (edge; edges.byKey) {
            edge.strahler(id);
            if (edge.rank > max) {
                count = 1;
                max = edge.rank;
            } else if (edge.rank == max) {
                count++;
            }
        }
        if (count >= 2)
            rank = max+1;
        else
            rank = max;
    }
    */
    
    ulong strahler(Function f, ulong new_id) {
        if (active) return 0;
        
        active = true;
        scope (exit) active = false;
        
        if (new_id != this.id)
            s = 0;
        
        if (s > 0 && !unstable)
            return s;
        if (edges.length == 0) {
            s = 1;
            return 1;
        }
        
        if (f !is null && f in edges) {
            unstable = true;
        }
        
        ulong max, count;
        foreach (edge; edges.byKey) {
            if (edge == f)
                continue;
            if (edge == this)
                continue;
            
            ulong es = edge.strahler(this, new_id);
            
            if (es > max) {
                count = 1;
                max = es;
            } else if (es == max) {
                count++;
            }
        }
        if (count >= 2)
            s = max + 1;
        else
            s = max;
        return s;
    }
    
    void reset() {
        s = 0;
        unstable = false;
    }
}
/*
private void strahler(Function f, Function[] fns) {
    if (visited) return;
    f.visited = true;
    if (f.edge.length == 0) {
        f.rank = 1;
    }
    foreach (edge; f.edges) {
        foreach (f2; fns) {
            if (f2.node == edge) {
                strahler(f2);
                break;
            }
        }
    }
}
*/
