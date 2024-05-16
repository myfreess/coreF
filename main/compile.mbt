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
    append(compileE(self, env), List::[Update(arity), Unwind])
  } else {
    append(compileE(self, env), List::[Update(arity), Pop(arity), Unwind])
  }
}

fn compileC(self : RawExpr[String], env : List[(String, Int)]) -> List[Instruction] {
  match self {
    Var(s) => {
      match lookupENV(env, s) {
        None => List::[PushGlobal(s)]
        Some(n) => List::[Push(n)]
      }
    }
    Num(n) => List::[PushInt(n)]
    App(App(Constructor(1, 2), x), xs) => {
      // Cons(x, xs)
      compileC(xs, env) + compileC(x, argOffset(1, env)) + List::[Pack(1, 2)]
    }
    App(e1, e2) => {
      append(compileC(e2, env), append(compileC(e1, argOffset(1, env)), List::[MkApp]))
    }
    Let(rec, defs, e) => {
      if rec {
        compileLetrec(compileC, defs, e, env)
      } else {
        compileLet(compileC, defs, e, env)
      }
    }
    Constructor(0, 0) => {
      // Nil
      List::[Pack(0, 0)]
    }
    _ => abort("not support yet")
  }
}

fn compileE(self : RawExpr[String], env : List[(String, Int)]) -> List[Instruction] {
  match self {
    Num(n) => List::[PushInt(n)]
    Let(rec, defs, e) => {
      if rec {
        compileLetrec(compileE, defs, e, env)
      } else {
        compileLet(compileE, defs, e, env)
      }
    }
    App(App(App(Var("if"), b), e1), e2) => {
      let condition = compileE(b, env)
      let branch1 = compileE(e1, env)
      let branch2 = compileE(e2, env)
      append(condition, List::[Cond(branch1, branch2)])
    }
    App(Var("negate"), e) => {
      append(compileE(e, env), List::[Neg])
    }
    App(App(Var(op), e0), e1) => {
      match builtinOpS[op] {
        None => append(compileC(self, env), List::[Eval]) // 不是primitive op, 走默认分支
        Some(instr) => {
          let code1 = compileE(e1, env)
          let code0 = compileE(e0, argOffset(1, env))
          append(code1, append(code0, List::[instr]))
        }
      }
    }
    Case(e, alts) => {
      compileE(e, env) + List::[CaseJump(compileAlts(alts, env))] 
    }
    Constructor(0, 0) => {
      // Nil
      List::[Pack(0, 0)]
    }
    App(App(Constructor(1, 2), x), xs) => {
      // Cons(x, xs)
      compileC(xs, env) + compileC(x, argOffset(1, env)) + List::[Pack(1, 2)]
    }
    _ => append(compileC(self, env), List::[Eval])
  }
}

fn compileAlts(alts : List[(Int, List[String], RawExpr[String])], env : List[(String, Int)]) -> List[(Int, List[Instruction])] {
  fn buildenv(variables : List[String], off : Int) -> List[(String, Int)] {
    match variables {
      Nil => Nil
      Cons(v, vs) => {
        Cons((v, off), buildenv(vs, off + 1))
      }
    }
  }
  fn go(alts : List[(Int, List[String], RawExpr[String])]) -> List[(Int, List[Instruction])] {
    match alts {
      Nil => Nil
      Cons(alt, rest) => {
        let (tag, variables, body) = alt
        let offset = length(variables)
        let env = buildenv(variables, 0) + argOffset(offset, env)
        let code = List::[Instruction::Split(offset)] + compileE(body, env) + List::[Slide(offset)]
        Cons((tag, code), go(rest))
      }
    }
  }
  go(alts)
}


fn compileLet(comp : (RawExpr[String], List[(String, Int)]) -> List[Instruction], defs : List[(String, RawExpr[String])], expr : RawExpr[String], env : List[(String, Int)]) -> List[Instruction] {
  let (env, codes) = loop env, List::Nil, defs {
    env, acc, Nil => (env, acc)
    env, acc, Cons((name, expr), rest) => {
      let code = compileC(expr, env)
      // 更新偏移量并加入name所对应的本地变量的偏移量
      let env = List::Cons((name, 0), argOffset(1, env))
      continue env, append(acc, code), rest
    }
  }
  append(codes, append(comp(expr, env), List::[Slide(length(defs))]))
}

fn compileLetrec(comp : (RawExpr[String], List[(String, Int)]) -> List[Instruction], defs : List[(String, RawExpr[String])], expr : RawExpr[String], env : List[(String, Int)]) -> List[Instruction] {
  let env = loop env, defs {
    env, Nil => env
    env, Cons((name, _), rest) => {
      let env = List::Cons((name, 0), argOffset(1, env))
      continue env, rest
    }
  }
  let n = length(defs)
  fn compileDefs(defs : List[(String, RawExpr[String])], offset : Int) -> List[Instruction] {
    match defs {
      Nil => append(comp(expr, env), List::[Slide(n)])
      Cons((_, expr), rest) => append(compileC(expr, env), Cons(Update(offset), compileDefs(rest, offset - 1)))
    }
  }
  Cons(Alloc(n), compileDefs(defs, n - 1))
}

fn argOffset(n : Int, env : List[(String, Int)]) -> List[(String, Int)] {
  map(fn (pair){
    let (name, offset) = pair
    (name, offset + n)
  }, env)
}

let builtinOpS : RHTable[String, Instruction] = {
  let table : RHTable[String, Instruction] = RHTable::new(50)
  table["add"] = Add 
  table["mul"] = Mul
  table["sub"] = Sub
  table["div"] = Div
  table["eq"]  = Eq
  table["neq"] = Ne
  table["ge"] = Ge 
  table["gt"] = Gt
  table["le"] = Le
  table["lt"] = Lt
  table
}

let compiledPrimitives : List[(String, Int, List[Instruction])] = List::[
  // 算术
  ("add", 2, List::[Push(1), Eval, Push(1), Eval, Add, Update(2), Pop(2), Unwind]),
  ("sub", 2, List::[Push(1), Eval, Push(1), Eval, Sub, Update(2), Pop(2), Unwind]),
  ("mul", 2, List::[Push(1), Eval, Push(1), Eval, Mul, Update(2), Pop(2), Unwind]),
  ("div", 2, List::[Push(1), Eval, Push(1), Eval, Div, Update(2), Pop(2), Unwind]),
  // 比较
  ("eq",  2, List::[Push(1), Eval, Push(1), Eval, Eq,  Update(2), Pop(2), Unwind]),
  ("neq", 2, List::[Push(1), Eval, Push(1), Eval, Ne,  Update(2), Pop(2), Unwind]),
  ("ge",  2, List::[Push(1), Eval, Push(1), Eval, Ge,  Update(2), Pop(2), Unwind]),
  ("gt",  2, List::[Push(1), Eval, Push(1), Eval, Gt,  Update(2), Pop(2), Unwind]),
  ("le",  2, List::[Push(1), Eval, Push(1), Eval, Le,  Update(2), Pop(2), Unwind]),
  ("lt",  2, List::[Push(1), Eval, Push(1), Eval, Lt,  Update(2), Pop(2), Unwind]),
  // 杂项
  ("negate", 1, List::[Push(0), Eval, Neg, Update(1), Pop(1), Unwind]),
  ("if",     3,  List::[Push(0), Eval, Cond(List::[Push(1)], List::[Push(2)]), Update(3), Pop(3), Unwind])
]