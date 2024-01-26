type Addr Int derive(Eq, Show)

fn hash(self : Addr) -> Int {
  let Addr(i) = self
  i.hash()
}

enum Node {
  NNum(Int)
  NApp(Addr, Addr)
  NGlobal(Int, List[Instruction])
  NInd(Addr)
} derive (Eq, Show)

struct GHeap {
  mut objectCount : Int
  memory : Array[Option[Node]]
}

type GStats Int

let statInitial : GStats = GStats(0)

fn statInc(self : GStats) -> GStats {
  let GStats(n) = self
  GStats(n + 1)
}

fn statGet(self : GStats) -> Int {
  let GStats(n) = self
  return n
}

struct GState {
  mut stack : List[Addr]
  heap : GHeap
  globals : RHTable[String, Addr]
  code : List[Instruction]
  stats : GStats
}

fn putStack(self : GState, addr : Addr) {
  self.stack = Cons(addr, self.stack)
}

fn pop1(self : GState) -> Addr {
  match self.stack {
    Cons(addr, reststack) => {
      self.stack = reststack
      addr
    }
    otherwise => {
      abort("pop1: stack size smaller than 1")
    }
  } 
}

fn pop2(self : GState) -> (Addr, Addr) {
  // 弹出栈顶两个元素
  // 返回(第一个， 第二个)
  match self.stack {
    Cons(addr1, Cons(addr2, reststack)) => {
      self.stack = reststack
      (addr1, addr2)
    }
    otherwise => {
      abort("pop2: stack size smaller than 2")
    }
  }
}



fn alloc(self : GHeap, node : Node) -> Addr {
  let heap = self
  // 假设堆中还有空余位置
  fn next(n : Int) -> Int {
    (n + 1) % heap.memory.length()
  }
  fn free(i : Int) -> Bool {
    match heap.memory[i] {
      None => true
      _    => false
    }
  }
  let mut i = heap.objectCount
  while not(free(i)) {
    i = next(i)
  }
  heap.memory[i] = Some(node)
  return Addr(i)
}

fn op_get(self : GHeap, key : Addr) -> Node {
  let Addr(i) = key
  match self.memory[i] {
    Some(node) => node
    None => abort("GHeap::get(): index \(i) was empty")
  }
}

fn pushglobal(name : String, vmstate : GState) {
  let sc = vmstate.globals[name]
  match sc {
    None => abort("pushglobal(): cant find supercombinator \(name)")
    Some(addr) => {
      vmstate.putStack(addr)
    }
  }
}

fn pushint(self : GState, num : Int) {
  let addr = self.heap.alloc(NNum(num))
  self.putStack(addr)
}

fn mkapp(self : GState) {
  let (a1, a2) = self.pop2()
  let appaddr = self.heap.alloc(NApp(a1, a2))
  self.putStack(appaddr)
}

fn pusharg(self : GState, offset : Int) {
  // 跳过首个超组合子节点
  // 访问第offset + 1个节点
  let appaddr = nth(self.stack, offset + 1)
  let arg = match self.heap[appaddr] {
    NApp(_, arg) => arg
    otherwise => abort("pusharg: stack offset \(offset) address \(appaddr) node \(otherwise), not a applicative node")
  }
  self.putStack(arg)
} 

fn slide(self : GState, n : Int) {
  let addr = self.pop1()
  self.stack = Cons(addr, drop(self.stack, n))
}