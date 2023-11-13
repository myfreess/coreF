pub struct Producer[T] {
  prod : ((T) -> Unit) -> Unit
}

pub fn yield[T](x : T) -> Producer[T] {
  fn prod(consume : (T) -> Unit) {
    consume(x)
  }
  return { prod : prod }
}

pub fn then[T](self : Producer[T], f : ((T) -> Unit) -> Unit) -> Producer[T] {
  fn prod(consume : (T) -> Unit) {
    (self.prod)(consume)
    f(consume)
  }
  return { prod : prod }
}

pub fn runWith[T](self : Producer[T], consume : (T) -> Unit) {
  (self.prod)(consume)
}

pub fn foldG[S, T](self : Producer[T], init: S, update : (S, T) -> S) -> S {
  var state = init
  fn consume(val) {
    state = update(state, val)
  }
  (self.prod)(consume)
  return state
}

