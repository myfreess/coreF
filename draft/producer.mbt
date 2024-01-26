pub struct Producer[T] {
  prod : ((T) -> Unit) -> Unit
}

pub fn Producer::empty[T]() -> Producer[T] {
  let do_nothing : Producer[T] = { prod : fn (consume) {}}
  return do_nothing
}

pub fn yield[T](x : T) -> Producer[T] {
  fn prod(consume : (T) -> Unit) {
    consume(x)
  }
  return { prod : prod }
}


// m.then(fn () {
//  
// })
pub fn then[T](self : Producer[T], f : () -> Producer[T]) -> Producer[T] {
  fn prod(consume : (T) -> Unit) {
    (self.prod)(consume)
    (f().prod)(consume)
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