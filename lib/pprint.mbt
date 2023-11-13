pub struct Producer[T] {
  prod : ((T) -> Unit) -> Unit
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

pub enum Doc {
  Text(String)
  Line
  Append(Doc, Doc)
  Group(Doc)
}

pub fn concatDoc(arr : Array[Doc]) -> Doc {
  var result = arr[arr.length() - 1]
  var i = arr.length() - 2
  while i >= 0 {
    result = Append(arr[i], result)
    i = i - 1
  }
  return result
}

