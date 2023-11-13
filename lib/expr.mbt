pub struct Alter[T] {
  tag : Int
  vars : List[T]
  exp : Expr[T]
}


pub enum Expr[T] {
  EVar(String)
  Enum(Int)
  EConstructor(Int, Int) // tag, arity
  EAp(Expr[T], Expr[T])
  ELet(Bool, List[(T, Expr[T])], Expr[T]) // isRec, Defs, Body
  ECase(Expr[T], List[Alter[T]])
  ELam(List[T], Expr[T])
}

pub fn isAtom[T](self : Expr[T]) -> Bool {
  match self {
    EVar(_) => true
    Enum(_) => true
    _ => false
  }
}

// 给ELet用的常量
let recursive = true
let nonRecursive = false

pub fn bindersOf[L, R](l : List[(L, R)]) -> List[L] {
  abort("")
}

pub struct ScDef[T] {
  name : String
  args : List[T]
  body : Expr[T]
}

