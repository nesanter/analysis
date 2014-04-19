class State(T) {
    State[T] edges;
    bool end;
    this(State[T] edges, bool end) {
        this.edges = edges;
        this.end = end;
    }
    
    bool select(const T[] input) {
        if (input.length == 0)
            return end;
        if (input[0] !in edges)
            return false;
        return edges[input[0]].select(input[1..$]);
    }
}

