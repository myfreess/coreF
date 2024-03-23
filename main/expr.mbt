enum RawExpr[T] {
  Var(T)
  Num(Int)
  Constructor(Int, Int) // tag, arity
  App(RawExpr[T], RawExpr[T])
  Let(Bool, List[(T, RawExpr[T])], RawExpr[T]) // isRec, Defs, Body
  Case(RawExpr[T], List[(Int, List[T], RawExpr[T])])
} derive (Debug)

fn to_string[T : Show](self : RawExpr[T]) -> String {
   match self {
     Var(v) => "(Var \(v))"
     Num(n) => "(Num \(n))"
     Constructor(tag, arity) => "(Constructor \(tag) \(arity))"
     App(f, x) => "(Apply \(f) \(x))"
     Let(isRec, defs, exp) => {
       if isRec {
         let defs = map(tuple2_str, defs).to_string()
         "(Letrec \(defs) \(exp))"
       } else {
         let defs = map(tuple2_str, defs).to_string()
         "(Let \(defs) \(exp))"
       }
     }
     Case(exp, alts) => {
       let alts = map(tuple3_str, alts).to_string()
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
  map(fst, l)
}

fn rhssOf[L, R](l : List[(L, R)]) -> List[R] {
  fn snd(pair) {
    let (_, r) = pair
    return r
  }
  map(snd, l)
}

struct ScDef[T] {
  name : String
  args : List[T]
  body : RawExpr[T]
} derive (Debug, Show)

fn ScDef::new[T](name : String, args : List[T], body : RawExpr[T]) -> ScDef[T] {
  { name : name, args : args, body : body }
}

let preludeDefs : List[ScDef[String]] = {
  let id = ScDef::new("I", arglist1("x"), Var("x")) // id x = x
  let k = ScDef::new("K", arglist2("x", "y"), Var("x")) // K x y = x
  let k1 = ScDef::new("K1", arglist2("x", "y"), Var("y")) // K1 x y = y
  let s = ScDef::new("S", arglist3("f", "g", "x"), App(App(Var("f"), Var("x")), App(Var("g"), Var("x")))) // S f g x = f x (g x)
  let compose = ScDef::new("compose", arglist3("f", "g", "x"), App(Var("f"), App(Var("g"), Var("x")))) // compose f g x = f (g x)
  let twice = ScDef::new("twice", arglist1("f"), App(App(Var("compose"), Var("f")), Var("f"))) // twice f = compose f f
  List::[id, k, k1, s, compose, twice]
}