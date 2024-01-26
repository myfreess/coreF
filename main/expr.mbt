enum RawExpr[T] {
  Var(T)
  Num(Int)
  Constructor(Int, Int) // tag, arity
  App(RawExpr[T], RawExpr[T])
  Let(Bool, List[(T, RawExpr[T])], RawExpr[T]) // isRec, Defs, Body
  Case(RawExpr[T], List[(Int, List[T], RawExpr[T])])
}

 fn to_string[T : Show](self : RawExpr[T]) -> String {
   match self {
     Var(v) => "(Var \(v))"
     Num(n) => "(Num \(n))"
     Constructor(tag, arity) => "(Constructor \(tag) \(arity))"
     App(f, x) => "(Apply \(f) \(x))"
     Let(isRec, defs, exp) => {
       if isRec {
         let defs = map(defs, tuple2_str).to_string()
         "(Letrec \(defs) \(exp))"
       } else {
         let defs = map(defs, tuple2_str).to_string()
         "(Let \(defs) \(exp))"
       }
     }
     Case(exp, alts) => {
       let alts = map(alts, tuple3_str).to_string()
       "(Case \(exp) \(alts))"
     }
   }
 }
 
fn isAtom[T](self : RawExpr[T]) -> Bool {
  match self {
    Var(_) => true
    Num(_) => true
    _ => false
  }
}

// 给ELet用的常量
let recursive = true
let nonRecursive = false

fn bindersOf[L, R](l : List[(L, R)]) -> List[L] {
  fn fst(pair) {
    let (l, _) = pair
    return l
  }
  map(l, fst)
}

fn rhssOf[L, R](l : List[(L, R)]) -> List[R] {
  fn snd(pair) {
    let (_, r) = pair
    return r
  }
  map(l, snd)
}

struct ScDef[T] {
  name : String
  args : List[T]
  body : RawExpr[T]
} derive (Show)

fn ScDef::new[T](name : String, args : List[T], body : RawExpr[T]) -> ScDef[T] {
  { name : name, args : args, body : body }
}

let preludeDefs : List[ScDef[String]] = {
  let id = ScDef::new("I", arglist1("x"), Var("x"))
  let k = ScDef::new("K", arglist2("x", "y"), Var("y"))
  let k1 = ScDef::new("K1", arglist2("x", "y"), Var("y"))
  let s = ScDef::new("S", arglist3("f", "g", "x"), App(App(Var("f"), Var("x")), App(Var("g"), Var("x"))))
  let compose = ScDef::new("compose", arglist3("f", "g", "x"), App(Var("f"), App(Var("g"), Var("x"))))
  let twice = ScDef::new("twice", arglist1("f"), App(App(Var("compose"), Var("f")), Var("f")))
  Cons(id, Cons(k, Cons(k1, Cons(s, Cons(compose, Cons(twice, Nil))))))
}