fn compileSC(self : ScDef[String]) -> (String, Int, List[Instruction]) {
  let name = self.name
  let body = self.body
  let mut arity = 0
  fn gen_env(i : Int, args : List[String]) -> List[(String, Int)] {
    match args {
      Nil => {
        arity = i
        return Nil
      }
      Cons(s, ss) => Cons((s, i), gen_env(i + 1, ss))
    }
  }
  let env = gen_env(0, self.args)
  (name, arity, compileR(body, env, arity))
}

fn compileR(self : RawExpr[String], env : List[(String, Int)], arity : Int) -> List[Instruction] {
  if arity == 0 {
    // 指令Pop 0实际上什么也没做，故 arity == 0 时不生成
    append(compileC(self, env), Cons(Update(arity), Cons(Unwind, Nil)))
  } else {
    append(compileC(self, env), Cons(Update(arity), Cons(Pop(arity), Cons(Unwind, Nil))))
  }
}

fn compileC(self : RawExpr[String], env : List[(String, Int)]) -> List[Instruction] {
  match self {
    Var(s) => {
      match lookupENV(env, s) {
        None => Cons(PushGlobal(s), Nil)
        Some(n) => Cons(PushArg(n), Nil)
      }
    }
    Num(n) => Cons(PushInt(n), Nil)
    App(e1, e2) => {
      append(compileC(e2, env), append(compileC(e1, argOffset(1, env)), Cons(MkApp, Nil)))
    }
    _ => abort("not support yet")
  }
}

fn argOffset(n : Int, env : List[(String, Int)]) -> List[(String, Int)] {
  map(fn (pair){
    let (name, offset) = pair
    (name, offset + n)
  }, env)
}

