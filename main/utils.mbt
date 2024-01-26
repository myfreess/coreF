fn map[X, Y](this: List[X], f: (X) -> Y) -> List[Y] {
  match this {
    Nil => Nil
    Cons(x, rest) => Cons(f(x), map(rest, f))
  }
}

fn exist[T : Eq](this : Array[T], elem : T) -> Bool {
  let mut i = 0
  while i < this.length(), i = i + 1 {
    if this[i] == elem {
      return true
    }
  }
  return false
}


fn todo[T](todo : String) -> T {
  abort("TODO: \(todo)")
}

fn reverse[X](this: List[X]) -> List[X] {
  fn go(acc, xs: List[X]) {
    match xs {
      Nil => acc
      Cons(x, rest) => go((Cons(x, acc) : List[X]), rest)
    }
  }
  go(Nil, this)
}

fn tuple2_str[L : Show, R : Show](t : (L, R)) -> String {
  let (x, y) = t
  "(" + x.to_string() + ", " + y.to_string() + ")"
}

fn tuple3_str[X : Show, Y : Show, Z : Show](t : (X, List[Y], Z)) -> String {
  let (x, y, z) = t
  "(" + x.to_string() + ", " + y.to_string() + ", " + z.to_string() + ")"
}


fn arglist1[T](arg1 : T) -> List[T] {
  Cons(arg1, Nil)
}

fn arglist2[T](arg1 : T, arg2 : T) -> List[T] {
  Cons(arg1, Cons(arg2, Nil))
}

fn arglist3[T](arg1 : T, arg2 : T, arg3 : T) -> List[T] {
  Cons(arg1, Cons(arg2, Cons(arg3, Nil)))
}

fn nth[T](lst : List[T], n : Int) -> T {
  match lst {
    Nil => abort("nth() : list length too small")
    Cons(x, xs) => {
      if n == 0 {
        x
      } else {
        nth(xs, n - 1)
      }
    }
  }
}

fn drop[T](lst : List[T], n : Int) -> List[T] {
  match lst {
    Nil => Nil
    Cons(x, xs) => {
      if n == 0 {
        lst
      } else {
        drop(xs, n - 1)
      }
    }
  }
}