fn map[X, Y](self: List[X], f: (X) -> Y) -> List[Y] {
  match self {
    Nil => Nil
    Cons(x, rest) => Cons(f(x), map(rest, f))
  }
}

