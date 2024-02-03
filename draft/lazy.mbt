enum LazyData[T] {
  Waiting(() -> T)
  Done(T)
}

struct LazyRef[T] {
  mut data : LazyData[T]
}

fn extract[T](self : LazyRef[T]) -> T {
  match self.data {
    Waiting(thunk) => {
      let value = thunk()
      self.data = Done(value)
      value
    }
    Done(value) => value
  }
}

fn square(x : LazyRef[Int]) -> Int {
  x.extract() * x.extract()
}


enum Stream[T] {
  Empty
  Cons(T, () -> Stream[T])
}

fn Stream::fromList[T](l : List[T]) -> Stream[T] {
  match l {
    Nil => Empty
    Cons(x, xs) => Cons(x, fn () { Stream::fromList(xs) })
  }
}

fn stream_map[X, Y](self : Stream[X], f : (X) -> Y) -> Stream[Y] {
  match self {
    Empty => Empty
    Cons(x, xs) => Cons(f(x), fn () { xs().stream_map(f) })
  }
} 

fn take[T](self : Stream[T], n : Int) -> List[T] {
  if n == 0 {
    Nil
  } else {
    match self {
      Empty => Nil
      Cons(x, xs) => Cons(x, xs().take(n - 1))
    }
  }
}