fn map[X, Y](self: List[X], f: (X) -> Y) -> List[Y] {
  match self {
    Nil => Nil
    Cons(x, rest) => Cons(f(x), map(rest, f))
  }
}

fn contains[T : Eq](self : Array[T], elem : T) -> Bool {
  var i = 0
  while i < self.length() {
    if self[i] == elem {
      return true
    }
    i = i + 1
  }
  return false
}

fn to_string[T : Show](self : List[T]) -> String {
  fn go(ls : List[T]){
    match ls {
      Nil => ""
      Cons(x,Nil) => "\(x)"
      Cons(x,xs) => "\(x), " + go(xs)
    }
  }
  "[" + go(self) + "]"
}

fn then[X, Y](self : Option[X], kont : (X) -> Option[Y]) -> Option[Y] {
  match self {
    None => None
    Some(v) => kont(v)
  }
}

fn failed[T](self : Option[T]) -> Bool {
  match self {
    None => true
    _ => false
  }
}

fn todo[T](todo : String) -> T {
  abort("TODO: \(todo)")
}

fn reverse[X](self: List[X]) -> List[X] {
  fn go(acc, xs: List[X]) {
    match xs {
      Nil => acc
      Cons(x, rest) => go((Cons(x, acc) : List[X]), rest)
    }
  }
  go(Nil, self)
}

fn tuple2_str[L : Show, R : Show](t : (L, R)) -> String {
  let (x, y) = t
  "(" + x.to_string() + ", " + y.to_string() + ")"
}

fn tuple3_str[X : Show, Y : Show, Z : Show](t : (X, Y, Z)) -> String {
  let (x, y, z) = t
  "(" + x.to_string() + ", " + y.to_string() + ", " + z.to_string() + ")"
}