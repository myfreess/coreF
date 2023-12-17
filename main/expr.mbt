enum RawExpr[T] {
  Var(T)
  Num(Int)
  Constructor(Int, Int) // tag, arity
  Ap(RawExpr[T], RawExpr[T])
  Let(Bool, List[(T, RawExpr[T])], RawExpr[T]) // isRec, Defs, Body
  Case(RawExpr[T], List[(Int, List[T], RawExpr[T])])
  Lam(List[T], RawExpr[T])
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
  l.map(fst)
}

fn rhssOf[L, R](l : List[(L, R)]) -> List[R] {
  fn snd(pair) {
    let (_, r) = pair
    return r
  }
  l.map(snd)
}

struct ScDef[T] {
  name : String
  args : List[T]
  body : RawExpr[T]
}

