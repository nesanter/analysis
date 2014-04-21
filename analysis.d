import std.stdio;
import std.conv;
import core.exception;
import std.getopt;
import std.traits;

import statemachine;
import opcode;
import defs;
static import backend.stats;
static import backend.printer;

Backend[] analysis_types;

void main(string[] args) {
    
    bool help;
    string iset_name = "iset.txt";
    
    try {
        try {
            getopt(args,
                std.getopt.config.passThrough,
                "help", &help,
                "type|t", &set_type,
                "iset", &iset_name
            );
        } catch (UnknownBackendException be) {
            writeln("failed to parse commandline (unknown backend ",be.bad_backend,")");
            return;
        }
    } catch (Exception e) {
        writeln("failed to parse commandline");
        return;
    }
    
    if (args.length == 1 || help) {
        display_help();
        return;
    }
    
    File isetfile;
    
    try {
        isetfile = File(iset_name,"r");
    } catch {
        writeln("Unable to open ",iset_name);
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
    
    try {
        id.parse(opload);
    } catch (ParseException e) {
        writeln("Internal error: ",e.msg);
        return;
    }
    
    run_backends(analysis_types, id.instructions);
}

void set_type(string opt, string val) {
    foreach (t; EnumMembers!Backend) {
        if (val == to!string(t)) {
            analysis_types ~= t;
            return;
        }
    }
    throw new UnknownBackendException("Error: unknown backend", val);
}

void display_help() {
    writeln("Syntax: analysis [options] filename");
    writeln("  options:");
    writeln("    --help\tdisplay this message");
    writeln("    --iset\tselect instruction set definitions");
    writeln("  backends:");
    string s;
    foreach (i,b; EnumMembers!Backend) {
        writeln("    --type=",to!string(b));
    }
}

class InstructionData {
    Instruction[] instructions;
    ulong[string] unknown_instructions;
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
                                    //writeln("prefix = ",i.inst);
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
                i.opc = unknown_opcode(i.inst);
                if (i.inst in unknown_instructions) {
                    unknown_instructions[i.inst]++;
                } else {
                    unknown_instructions[i.inst] = 1;
                }
            }
            foreach (o; i.operands) {
                if (is_register(o.raw, o.rc)) {
                    o.type = OperandType.Register;
                } else if (is_mem_access(o.raw)) {
                    o.type = OperandType.Indirection;
                    o.subops = split_indirection(o.raw);
                } else if (is_constant(o.raw, o.val)) {
                    o.type = OperandType.Constant;
                } else {
                    o.type = OperandType.Unknown;
                    writeln("unknown: ",i.raw);
                }
                //writeln(o);
            }
        }
    }
}




State!char regcheck;

void init_state_machine() {
    //covers a, b, c, d, si, di, sp, bp, ip
    // plus stack registers and control registers
    State!char[char] empty;
    auto sx = new State!char(empty,true);
    auto sl = new State!char(empty,true);
    auto sh = new State!char(empty,true);
    auto si1 = new State!char(empty,true,RegClass.convert_to_i);
    auto sse = new State!char(empty,true,RegClass.seg);
    auto sce = new State!char(empty,true,RegClass.other);
    auto snb = new State!char(empty,true);
    auto snw = new State!char(empty,true);
    auto snd = new State!char(empty,true);
    auto s0 = new State!char(['b':snb,'w':snw,'d':snd],true,RegClass.r10);
    auto s1b = new State!char(['b':snb,'w':snw,'d':snd],true,RegClass.r11);
    auto s2 = new State!char(['b':snb,'w':snw,'d':snd],true,RegClass.r12);
    auto s3 = new State!char(['b':snb,'w':snw,'d':snd],true,RegClass.r13);
    auto s4 = new State!char(['b':snb,'w':snw,'d':snd],true,RegClass.r14);
    auto s5 = new State!char(['b':snb,'w':snw,'d':snd],true,RegClass.r15);
    auto s8 = new State!char(['b':snb,'w':snw,'d':snd],true,RegClass.r8);
    auto s9 = new State!char(['b':snb,'w':snw,'d':snd],true,RegClass.r9);
    auto s1 = new State!char(['0':s0,'1':s1b,'2':s2,'3':s3,'4':s4,'5':s5],false);
    auto scr = new State!char(['0':sce,'1':sce,'2':sce,'3':sce,'4':sce],false);
    auto si2 = new State!char(['h':sh,'l':sl],true,RegClass.convert_to_i);
    auto sp1 = new State!char(empty,true,RegClass.convert_to_p);
    auto sp2 = new State!char(['h':sh,'l':sl],true,RegClass.convert_to_p);
    auto sa1 = new State!char(['x':sx],false,RegClass.a);
    auto sb1 = new State!char(['x':sx,'p':sp1],false,RegClass.b);
    auto sc1 = new State!char(['x':sx],false,RegClass.c);
    auto sd1 = new State!char(['x':sx,'i':si1],false,RegClass.d);
    auto ss1 = new State!char(['i':si1,'p':sp1],true,RegClass.tmp_s,RegClass.seg);
    auto sa2 = new State!char(['x':sx,'h':sh,'l':sl],false,RegClass.a);
    auto sb2 = new State!char(['x':sx,'h':sh,'l':sl,'p':sp2],false,RegClass.b);
    auto sc2 = new State!char(['x':sx,'h':sh,'l':sl,'s':sse,'r':scr],false,RegClass.c);
    auto sd2 = new State!char(['x':sx,'h':sh,'l':sl,'i':si2,'s':sse],false,RegClass.d);
    auto ss2 = new State!char(['i':si2,'p':sp2,'s':sse],false,RegClass.tmp_s);
    auto sf2 = new State!char(['s':sse],false,RegClass.other);
    auto sg2 = new State!char(['s':sse],false,RegClass.other);
    auto sipe = new State!char(empty,true,RegClass.ip);
    auto sip = new State!char(['p':sipe],false);
    auto sr = new State!char(['a':sa1,'b':sb1,'c':sc1,'d':sd1,'s':ss1,'8':s8,'9':s9,'1':s1,'i':sip],false);
    auto se = new State!char(['a':sa1,'b':sb1,'c':sc1,'d':sd1,'s':ss1, 'i':sip],false);
    regcheck = new State!char(['r':sr,'e':se,'a':sa2,'b':sb2,'c':sc2,'d':sd2,'s':ss2,
                               'f':sf2,'g':sg2,'i':sip],false);
}

bool is_register(string operand, ref RegClass cl) {
    return regcheck.select(operand,cl);
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

Operand[] split_indirection(string s) {
    Operand[] subops;
    
    //find PTR and discard
    foreach (i; 0 .. s.length-4) {
        if (s[i..i+4] == "PTR ") {
            s = s[i+4..$];
            break;
        }
    }
    
    //find immediate segment
    while (s.length > 2 && s[0..2] == "0x") {
        ulong i = 2;
        while (i < s.length) {
            if (s[i] == ':') {
                subops ~= new Operand;
                subops[$-1].raw = s[2..i];
                subops[$-1].type = OperandType.Constant;
                if (!is_constant(s[2..i],subops[$-1].val)) {
                    throw new ParseException("Unable to parse indirection (bad segment)");
                }
                s = s[i+1..$];
                break;
            } else
                i++;
        }
        if (i >= s.length)
            break;
    }
    
    //find segments
    while (s.length > 2 && s[2] == ':') {
        subops ~= new Operand;
        subops[$-1].raw = s[0..2];
        if (is_register(s[0..2],subops[$-1].rc)) {
            subops[$-1].type = OperandType.Register;
            s = s[3..$];
        } else {
            throw new ParseException("Unable to parse indirection (unknown segment)");
        }
    }
    
    //find []
    if (s.length > 0 && s[0] == '[') {
        s = s[1..$];
        bool stop = false;
        while (!stop) {
            Operand op = new Operand;
            foreach (i; 0 .. s.length) {
                if (s[i] == '+' || s[i] == '-' || s[i] == '*' || s[i] == ']') {
                    op.raw = s[0..i];
                    if (is_register(s[0..i],op.rc)) {
                        op.type = OperandType.Register;
                    } else if (is_constant(s[0..i],op.val)) {
                        op.type = OperandType.Constant;
                    } else if (s[i-1] == 'z') {
                        op.type = OperandType.Constant;
                        op.val = 0;
                    } else {
                        throw new ParseException("Unable to parse indirection (not reg/imm)");
                    }
                    subops ~= op;
                    
                    if (s[i] == ']')
                        stop = true;
                    
                    s = s[i+1..$];
                    break;
                }
            }
        }
        if (s.length > 1) //remove +
            s = s[1..$];
    }
    
    //find constant
    if (s.length > 0) {
        subops ~= new Operand;
        subops[$-1].raw = s;
        subops[$-1].type = OperandType.Constant;
        if (!is_constant(s,subops[$-1].val)) {
            throw new ParseException("Unable to parse indirection (bad constant)");
        }
    }
    
    if (subops.length == 0)
        throw new ParseException("Unable to parse indirection (no matches)");
    return subops;
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

void run_backends(Backend[] backends, Instruction[] instructions) {
    foreach (b; backends) {
        mixin(gen_run_backends());
    }
}

string gen_run_backends() {
    string s = "switch (b) {";
    foreach (b; EnumMembers!Backend) {
        if (b != Backend.none)
            s ~= "case Backend."~to!string(b)~": backend."~to!string(b)~".run(instructions); break;";
    }
    return s ~ "default: throw new UnknownBackendException(\"error in run backends\",to!string(b));}";
}
