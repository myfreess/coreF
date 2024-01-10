fn map[X, Y](this: List[X], f: (X) -> Y) -> List[Y] {
  match this {
    Nil => Nil
    Cons(x, rest) => Cons(f(x), map(rest, f))
  }
}

fn contains[T : Eq](this : Array[T], elem : T) -> Bool {
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
  "(" + x.to_string() + ", " + lst2str(y) + ", " + z.to_string() + ")"
}

struct Assoc[K, V] {
  data : Array[(K, V)]
}

fn op_get[K : Eq + Show, V](this : Assoc[K, V], key : K) -> V {
  let mut i = 0
  while i < this.data.length(), i = i + 1 {
    if this.data[i].0 == key {
      return this.data[i].1
    }
  }
  // 查找不到
  abort("Assoc::get(): \(key) not found")
}

fn lst2str[T : Show](this : List[T]) -> String {
  fn go(ls : List[T]){
    match ls {
      Nil => ""
      Cons(x,Nil) => "\(x)"
      Cons(x,xs) => "\(x) " + go(xs)
    }
  }
  "(" + go(this) + ")"
}