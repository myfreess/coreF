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