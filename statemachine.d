import defs;

class State(T) {
    State[T] edges;
    RegClass c, altc;
    bool end;
    this(State[T] edges, bool end, RegClass c = RegClass.none, RegClass altc = RegClass.none) {
        this.edges = edges;
        this.end = end;
        this.c = c;
        this.altc = altc;
    }
    
    bool select(const T[] input, ref RegClass rc) {
        if (c != RegClass.none) {
            if (c == RegClass.convert_to_i) {
                switch (rc) {
                    case RegClass.tmp_s:
                        rc = RegClass.si;
                    break;
                    case RegClass.d:
                        rc = RegClass.di;
                    break;
                    default:
                        throw new ParseException("Register identification error");
                    break;
                }
            } else if (c == RegClass.convert_to_p) {
                switch (rc) {
                    case RegClass.tmp_s:
                        rc = RegClass.sp;
                    break;
                    case RegClass.b:
                        rc = RegClass.bp;
                    break;
                    default:
                        throw new ParseException("Register identification error");
                    break;
                }
            } else {
                rc = c;
            }
        }
        if (input.length == 0) {
            if (altc != RegClass.none)
                rc = altc;
            return end;
        }
        if (input[0] !in edges)
            return false;
        return edges[input[0]].select(input[1..$], rc);
    }
}

