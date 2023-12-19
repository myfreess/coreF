fn testParse() {
  let number = "45676"
  let variable = "let-you_down"
  let application = "(foo bar)"
  let nest_application = "((foo bar) baz ccfc)"
  let let_example = "(let ([x (foo 43)]) x)"
  let sc1 = "(defn square[x] (mul x x))"
  println(parseSC(TokenStream::new(sc1)))
}


fn init {
  testParse()
}
