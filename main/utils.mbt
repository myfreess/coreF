fn map[X, Y](f: (X) -> Y, this: List[X]) -> List[Y] {
  match this {
    Nil => Nil
    Cons(x, rest) => Cons(f(x), map(f, rest))
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
    Cons(_, xs) => {
      if n == 0 {
        lst
      } else {
        drop(xs, n - 1)
      }
    }
  }
}

fn append[X](this: List[X], ys: List[X]) -> List[X] {
  match this {
    Nil => ys
    Cons(x, rest) => Cons(x, append(rest, ys))
  }
}

fn length[T](this: List[T]) -> Int {
  match this {
    Nil => 0
    Cons(_, xs) => 1 + length(xs)
  }
}

fn lookupENV[K : Eq + Show, V](this : List[(K, V)], key : K) -> Option[V] {
  match this {
    Nil => None
    Cons((k, v), rest) => {
      if k == key {
        Some(v)
      } else {
        lookupENV(rest, key)
      }
    }
  }
}

fn lst2str[T : Show](lst : List[T]) -> String {
  fn go(ls : List[T]){
    match ls {
      Nil => ""
      Cons(x,Nil) => "\(x)"
      Cons(x,xs) => "\(x), " + go(xs)
    }
  }
  match lst {
    Nil => "Nil"
    _ => go(lst)
  }
}