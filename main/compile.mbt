fn compileSC(self : ScDef[String]) -> (String, Int, List[Instruction]) {
  let name = self.name
  let body = self.body
  fn gen_env(i : Int, args : List[String]) -> List[(String, Int)] {
    match args {
      Nil => Nil
      Cons(s, ss) => Cons((s, i), gen_env(i + 1, ss))
    }
  }
  let env = gen_env(0, self.args)
  // compileR(body, )
  todo("compileSC")
}

fn argOffset(n : Int, env : List[(String, Int)]) -> List[(String, Int)] {
  map(env, fn (pair){
    let (name, offset) = pair
    (name, offset + n)
  })
}

