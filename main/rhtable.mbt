struct RingBuffer[T] {
  mut start : Int
  array : Array[T]
}

fn capacity[T](self : RingBuffer[T]) -> Int {
  self.array.length()
}

fn op_get[T](self : RingBuffer[T], idx : Int) -> T {
  let index = (self.start + idx) % self.capacity()
  self.array[index]
}

fn op_set[T](self : RingBuffer[T], idx : Int, val : T) {
  let index = (self.start + idx) % self.capacity()
  self.array[index] = val
}

fn fromArray[T](arr : Array[T]) -> RingBuffer[T] {
  { start : 0, array : arr }
}

enum Bucket[K, V] {
  Empty
  Tomb
  Store(Int, K, V) // offset key value
}

fn to_string[K : Show, V : Show](self : Bucket[K, V]) -> String {
  match self {
    Empty => "Empty"
    Tomb => "Tomb"
    Store(off, k, v) => "Store(\(off), \(k), \(v))"
  }
}

let loadFactor = 0.9

struct RHTable[K, V] {
  mut count : Int
  mut buckets : RingBuffer[Bucket[K, V]]
}

fn to_string[K : Show, V : Show](self : RHTable[K, V]) -> String {
  self.buckets.start = 0 //debug用数组的下标
  let mut str = "[| "
  let mut i = 0
  while i < self.buckets.capacity() {
    match self.buckets[i] {
      Store(off, k, v) => {
        str = str + "(\(k), \(v))-(offset=\(off), idx=\(i)) "
        i = i + 1
      }
      _ => {
        i = i + 1
      }
    }
  }
  str = str + "|]"
  return str
}

fn RHTable::new[K, V](capacity : Int) -> RHTable[K, V] {
  let mut capacity = capacity
  if capacity < 20 {
    capacity = 20 //初始容量搞大点
  }
  let arr : Array[Bucket[K, V]] = Array::make(capacity, Empty)
  let buckets = { start : 0, array : arr }
  { count : 0, buckets : buckets}
}

fn capacity[K, V](self : RHTable[K, V]) -> Int {
  self.buckets.capacity()
}

fn get_index_by[K : Hash, V](self : RHTable[K, V], key : K) -> Int {
  let n = key.hash() % self.buckets.capacity()
  if n < 0 {
    0 - n
  } else {
    n
  }
}

fn proportion[K, V](self:RHTable[K, V]) -> Double {
  self.count.to_double() / self.buckets.capacity().to_double()
}

fn insertWithoutGrowing[K : Hash, V](self : RHTable[K, V], key : K, val : V) {
  let start = self.get_index_by(key)
  self.buckets.start = start
  self.count = self.count + 1
  let mut key = key
  let mut val = val
  let mut offset = 0
  let mut i = 0
  while i < self.buckets.capacity() {
    match self.buckets[i] {
      Empty => {
        self.buckets[i] = Store(offset, key, val)
        break
      }
      Tomb => {
        self.buckets[i] = Store(offset, key, val)
        break
      }
      Store(off, k, v) => {
        if off < offset {
          // 交换内容
          self.buckets[i] = Store(offset, key, val)
          offset = off
          key = k
          val = v
          offset = offset + 1
          i = i + 1
        } else {
          offset = offset + 1
          i = i + 1
        }
      }
    }
  }
}

fn lookup[K : Hash + Eq, V](self : RHTable[K, V], key : K) -> Option[V] {
  let start = self.get_index_by(key)
  self.buckets.start = start
  let mut i = 0
  while i < self.buckets.capacity() {
    match self.buckets[i] {
      Empty => {
        return None
      }
      Tomb => {
        i = i + 1
      }
      Store(_, k, v) => {
        if k == key {
          return Some(v)
        } else {
          i = i + 1
        }
      }
    }
  }
  return None
}

fn delete[K : Hash + Eq, V](self : RHTable[K, V], key : K) -> Option[V] {
  // 删除成功则返回Some(v)
  let start = self.get_index_by(key)
  self.buckets.start = start
  let mut i = 0
  while i < self.buckets.capacity() {
    match self.buckets[i] {
      Empty => {
        return None
      }
      Tomb => {
        i = i + 1
      }
      Store(_, k, v) => {
        if key == k {
          self.buckets[i] = Tomb
          return Some(v)
        } else {
          i = i + 1
        }
      }
    }
  }
  return None
}

fn grow[K : Hash , V](self : RHTable[K, V]) {
  // 没考虑过self.capacity()等于零的情况
  let src : RingBuffer[Bucket[K, V]] = self.buckets
  let arr: Array[Bucket[K, V]] = Array::make(self.buckets.capacity() * 2, Empty)
  self.buckets = fromArray(arr)
  self.count = 0
  let mut i = 0
  src.start = 0
  while i < src.capacity() {
    match src[i] {
      Store(_, k, v) => {
        self.insertWithoutGrowing(k, v)
        i = i + 1
      }
      _ => {
        i = i + 1
      }
    }
  }
}

fn insert[K : Hash + Eq, V](self : RHTable[K, V], key : K, val : V) {
  if self.proportion() > loadFactor {
    self.grow()
  }
  self.insertWithoutGrowing(key, val)
}

fn op_get[K : Hash + Eq, V](self : RHTable[K, V], key : K) -> Option[V] {
  self.lookup(key)
}

fn op_set[K : Hash + Eq, V](self : RHTable[K, V], key : K, val : V) {
  self.insert(key, val)
}