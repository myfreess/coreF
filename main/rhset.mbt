struct RHSet[T] {
  set : RHTable[T, Unit]
}

fn RHSet::new[T](capacity : Int) -> RHSet[T] {
  let set : RHTable[T, Unit]= RHTable::new(capacity)
  { set : set }
}

fn contains[T : Hash + Eq](self : RHSet[T], elem : T) -> Bool {
  let result = self.set.lookup(elem)
  match result {
    Some(_) => true
    None    => false
  }
}

fn add[T : Hash + Eq](self : RHSet[T], elem : T) {
  self.set.insert(elem, ())
}

fn remove[T : Hash + Eq](self : RHSet[T], elem : T) -> Bool {
  match self.set.delete(elem) {
    Some(_) => true
    None    => false
  }
}

