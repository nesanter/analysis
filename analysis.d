import std.stdio;
import std.conv;
import core.exception;

import statemachine;
import opcode;

void main(string[] args) {
    
    if (args.length == 1 || args[1] == "help") {
        display_help();
        return;
    }
    
    File isetfile;
    
    try {
        isetfile = File("iset.txt","r");
    } catch {
        writeln("Unable to open iset.txt");
        return;
    }
    
    OpcodeLoader opload = new OpcodeLoader(isetfile, true);
    
    isetfile.close();
    
    init_state_machine();
    
    File infile;
    
    try {
        infile = File(args[1],"r");
    } catch (Exception e) {
        writeln("Unable to open ",args[1]);
        return;
    }
    
    InstructionData id = new InstructionData(infile,opload);
    
    infile.close();
    
    id.parse(opload);
    
    foreach (inst; id.instructions) {
        if (inst.prefix.length > 0) {
            writeln(inst.opc," ",inst.prefix);
            writeln(inst.raw);
        }
    }
    writeln("unknown instructions:");
    foreach (inst; id.unknown_instructions.byKey) {
        writeln(inst," (",id.unknown_instructions[inst],")");
    }
}


void display_help() {
    writeln("Syntax: analysis file_name");
}


class ParseException : Exception {
    this(string msg) {
        super(msg);
    }
}

class InstructionData {
    Instruction[] instructions;
    ulong[string] unknown_instructions;
    bool[string] prefix_list;
    //load raw instruction data from file
    this(File infile, OpcodeLoader opcld) {
        foreach (line; infile.byLine) {
            if (line.length < 2) continue;
            if (line[0..2] != "  ") continue;
            Instruction i = new Instruction;
            ulong mode = 0;
            foreach (ch; line[2..$]) {
                i.raw ~= ch;
                final switch (mode) {
                    case 0:
                        if (ch == ':') {
                            mode = 1;
                        } else {
                            i.address = (i.address << 4) + ch_to_hex(ch);
                        }
                    break;
                    case 1:
                        if (ch != ' ' && ch != '\t') {
                            mode = 2;
                            goto case 2;
                        }
                    break;
                    case 2:
                        if (ch == ' ') {
                            if (i.inst in opcld.opcodes) {
                                if (opcld.opcodes[i.inst].flag_prefix) {
                                    writeln("prefix = ",i.inst);
                                    if (opcld.opcodes[i.inst].type == OpcodeType.Ignore) {
                                        //do nothing
                                    } else {
                                        //add as prefix
                                        i.prefix ~= opcld.opcodes[i.inst];
                                    }
                                    i.inst = "";
                                } else {
                                    mode = 3;
                                }
                            } else {
                                mode = 3;
                            }
                        } else {
                            i.inst ~= ch;
                        }
                    break;
                    case 3:
                        if (ch != ' ') {
                            mode = 4;
                            goto case 4;
                        }
                    break;
                    case 4:
                        if (i.operands.length == 0)
                            i.operands ~= new Operand;
                        if (ch == ',') {
                            i.operands ~= new Operand;
                        } else {
                            i.operands[$-1].raw ~= ch;
                        }
                    break;
                }
            }
            //writeln(i.inst);
            //writeln("address = ",i.address,", inst = ",i.inst,", operands = ",i.operands);
            instructions ~= i;
        }
    }
    //convert raw instruction data into analysis format
    void parse(OpcodeLoader opcld) {
        foreach (i; instructions) {
            if (i.inst in opcld.opcodes) {
                i.opc = opcld.opcodes[i.inst];
            } else {
                if (i.inst in unknown_instructions) {
                    unknown_instructions[i.inst]++;
                } else {
                    unknown_instructions[i.inst] = 1;
                }
            }
            foreach (o; i.operands) {
                //writeln(o.raw);
                if (is_register(o.raw)) {
                    o.type = OType.Register;
                } else if (is_mem_access(o.raw)) {
                    o.type = OType.Indirection;
                } else if (is_constant(o.raw, o.val)) {
                    o.type = OType.Constant;
                    //writeln(o.raw);
                } else {
                    o.type = OType.Unknown;
                    writeln("unknown: ",o.raw);
                    writeln("         ",i.raw);
                }
            }
        }
    }
}




State!char regcheck;

void init_state_machine() {
    //covers a, b, c, d, si, di, sp, bp
    // plus stack registers and control registers
    State!char[char] empty;
    auto sx = new State!char(empty,true);
    auto sl = new State!char(empty,true);
    auto sh = new State!char(empty,true);
    auto si1 = new State!char(empty,true);
    auto sse = new State!char(empty,true);
    auto sce = new State!char(empty,true);
    auto snb = new State!char(empty,true);
    auto snw = new State!char(empty,true);
    auto snd = new State!char(empty,true);
    auto s0 = new State!char(['b':snb,'w':snw,'d':snd],true);
    auto s1b = new State!char(['b':snb,'w':snw,'d':snd],true);
    auto s2 = new State!char(['b':snb,'w':snw,'d':snd],true);
    auto s3 = new State!char(['b':snb,'w':snw,'d':snd],true);
    auto s4 = new State!char(['b':snb,'w':snw,'d':snd],true);
    auto s5 = new State!char(['b':snb,'w':snw,'d':snd],true);
    auto s8 = new State!char(['b':snb,'w':snw,'d':snd],true);
    auto s9 = new State!char(['b':snb,'w':snw,'d':snd],true);
    auto s1 = new State!char(['0':s0,'1':s1b,'2':s2,'3':s3,'4':s4,'5':s5],false);
    auto scr = new State!char(['0':sce,'1':sce,'2':sce,'3':sce,'4':sce],false);
    auto si2 = new State!char(['h':sh,'l':sl],true);
    auto sp1 = new State!char(empty,true);
    auto sp2 = new State!char(['h':sh,'l':sl],true);
    auto sa1 = new State!char(['x':sx],false);
    auto sb1 = new State!char(['x':sx,'p':sp1],false);
    auto sc1 = new State!char(['x':sx],false);
    auto sd1 = new State!char(['x':sx,'i':si1],false);
    auto ss1 = new State!char(['i':si1,'p':sp1],true);
    auto sa2 = new State!char(['x':sx,'h':sh,'l':sl],false);
    auto sb2 = new State!char(['x':sx,'h':sh,'l':sl,'p':sp2],false);
    auto sc2 = new State!char(['x':sx,'h':sh,'l':sl,'s':sse,'r':scr],false);
    auto sd2 = new State!char(['x':sx,'h':sh,'l':sl,'i':si2,'s':sse],false);
    auto ss2 = new State!char(['i':si2,'p':sp2,'s':sse],false);
    auto sf2 = new State!char(['s':sse],false);
    auto sg2 = new State!char(['s':sse],false);
    auto sr = new State!char(['a':sa1,'b':sb1,'c':sc1,'d':sd1,'s':ss1,'8':s8,'9':s9,'1':s1],false);
    auto se = new State!char(['a':sa1,'b':sb1,'c':sc1,'d':sd1,'s':ss1],false);
    regcheck = new State!char(['r':sr,'e':se,'a':sa2,'b':sb2,'c':sc2,'d':sd2,'s':ss2,
                               'f':sf2,'g':sg2],false);
}

bool is_register(string operand) {
    return regcheck.select(operand);
}

bool is_mem_access(string operand) {
    foreach (ch; operand) {
        if (ch == '[' || ch == ':')
            return true;
    }
    return false;
}

bool is_constant(string operand, out ulong val) {
    val = 0;
    try {
        if (operand.length > 2 && operand[0..2] == "0x") {
            foreach (ch; operand[2..$]) {
                if (ch == ' ')
                    break;
                val = (val << 4) + ch_to_hex(ch);
            }
        } else {
            foreach (ch; operand[0..$]) {
                if (ch == ' ')
                    break;
                val = (val << 4) + ch_to_hex(ch);
            }
        }
    } catch (ParseException e) {
        return false;
    }
    return true;
}

class Instruction {
    Opcode opc;
    ulong address;
    Operand[] operands;
    Opcode[] prefix;
    string inst,raw;
}

enum OType {
    Constant, Register, Indirection, Unknown
}

class Operand {
    OType type;
    ulong val;
    string raw;
    override string toString() {
        return raw;
    }
}

ulong ch_to_hex(char ch) {
    if (ch >= 48 && ch < 58) {
        return ch - 48;
    } else if (ch >= 97 && ch < 103) {
        return ch - 87;
    }
    throw new ParseException("Expected hex character, got "~[ch]);
}
ulong ch_to_dec(char ch) {
    if (ch >= 48 && ch < 58) {
        return ch - 48;
    }
    throw new ParseException("Expected hex character, got "~[ch]);
}
