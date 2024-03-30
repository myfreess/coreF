

fn run(codes : List[String]) -> Unit {
  fn parse_then_compile(code : String) -> (String, Int, List[Instruction]) {
    let code = TokenStream::new(code)
    let code = parseSC(code)
    let code = compileSC(code)
    return code
  }
  let codes = append(map(parse_then_compile, codes), map(compileSC, preludeDefs))
  let codes = append(compiledPrimitives, codes)
  let (heap, globals) = buildInitialHeap(codes)
  let initialState : GState = {
    dump : initialDump,
    heap : heap,
    stack : Nil,
    code : initialCode,
    globals : globals,
    stats : initialStat
  }
  initialState.reify()
}


fn fulltest() -> Unit {
  let main = "(defn main[] (I (sub (add 4 5) 2)))"
  run(List::[main])
}

fn main {
  fulltest()
}
