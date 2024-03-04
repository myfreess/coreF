fn testParse() {
  let number = "45676"
  let variable = "let-you_down"
  let application = "(foo bar)"
  let nest_application = "((foo bar) baz ccfc)"
  let let_example = "(let ([x (foo 43)]) x)"
  let sc1 = "(defn square[x] (mul x x))"
  println(parseSC(TokenStream::new(sc1)))
}

fn testCompile() {
  let id = ScDef::new("I", arglist1("x"), Var("x"))
  let k = ScDef::new("K", arglist2("x", "y"), Var("x"))
  let k1 = ScDef::new("K1", arglist2("x", "y"), Var("y"))
  let s = ScDef::new("S", arglist3("f", "g", "x"), App(App(Var("f"), Var("x")), App(Var("g"), Var("x"))))
  let compose = ScDef::new("compose", arglist3("f", "g", "x"), App(Var("f"), App(Var("g"), Var("x"))))
  let twice = ScDef::new("twice", arglist1("f"), App(App(Var("compose"), Var("f")), Var("f")))
  let (name, arity, instrs) = compileSC(k)
  println("name = \(name)")
  println("arity = \(arity)")
  println("instrs = \(instrs)")
}

fn run(codes : List[String]) {
  fn parse_then_compile(code : String) -> (String, Int, List[Instruction]) {
    let code = TokenStream::new(code)
    let code = parseSC(code)
    let code = compileSC(code)
    return code
  }
  let codes = append(map(parse_then_compile, codes), map(compileSC, preludeDefs))
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


fn fulltest() {
  let main = "(defn main[] (letrec ([F (S K)] [X K]) (F X 3))" // => ((K x (K x)) => x
  run(Cons(main, Nil))
}

fn init {
  fulltest()
}
