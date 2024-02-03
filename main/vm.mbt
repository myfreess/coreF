type Addr Int derive(Eq, Show)

fn hash(self : Addr) -> Int {
  let Addr(i) = self
  i.hash()
}

enum Node {
  NNum(Int)
  NApp(Addr, Addr)
  NGlobal(String, Int, List[Instruction])
  NInd(Addr)
} derive (Eq, Show)

struct GHeap {
  mut objectCount : Int
  memory : Array[Option[Node]]
}

type GStats Int

let initialStat : GStats = GStats(0)

fn statInc(self : GState) {
  let GStats(n) = self.stats
  self.stats = GStats(n + 1)
}

fn statGet(self : GStats) -> Int {
  let GStats(n) = self
  return n
}

struct GState {
  mut stack : List[Addr]
  heap : GHeap
  globals : RHTable[String, Addr]
  mut code : List[Instruction]
  mut stats : GStats
}

fn step(self : GState) -> Bool {
  match self.code {
    Nil => { return false }
    Cons(i, is) => {
      self.code = is
      self.statInc()
    //  调试用语句
    //  let stack = lst2str(self.stack)
    //  let restcodes = lst2str(is)
    //  println("current stack : \(stack)")
    //  println("exec instruction \(i)")
    //  println("rest instructions \(restcodes)")
    //  let GStats(n) = self.stats
    //  println("stat = \(n)")
    //  println(" ")
      match i {
        PushGlobal(f) => self.pushglobal(f)
        PushInt(n) => self.pushint(n)
        PushArg(n) => self.pusharg(n)
        MkApp => self.mkapp()
        Slide(n) => self.slide(n)
        Unwind => self.unwind()
        Update(n) => self.update(n)
        Pop(n) => { self.stack = drop(self.stack, n) }
      }
      return true
    }
  }
}

fn reify(self : GState) {
  match self.step() {
    false => {
      let stack = self.stack
      match stack {
        Cons(addr, Nil) => {
          let res = self.heap[addr]
          println("\(res)")
        }
        _ => abort("wrong stack \(stack)")
      }
    
    }
    true => self.reify()
  }
}

fn buildInitialHeap(scdefs : List[(String, Int, List[Instruction])]) -> (GHeap, RHTable[String, Addr]) {
  let heap = { objectCount : 0, memory : Array::make(10000, None) }
  let globals = RHTable::new(50)
  fn loop(lst : List[(String, Int, List[Instruction])]) {
    match lst {
      Nil => ()
      Cons((name, arity, instrs), rest) => {
        let addr = heap.alloc(NGlobal(name, arity, instrs))
        globals[name] = addr
        loop(rest)
      }
    }
  }
  loop(scdefs)
  return (heap, globals)
}

let initialCode : List[Instruction] = Cons(PushGlobal("main"), Cons(Unwind, Nil))

fn putStack(self : GState, addr : Addr) {
  self.stack = Cons(addr, self.stack)
}

fn putCode(self : GState, is : List[Instruction]) {
  self.code = append(is, self.code)
}

fn pop1(self : GState) -> Addr {
  match self.stack {
    Cons(addr, reststack) => {
      self.stack = reststack
      addr
    }
    Nil => {
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

fn op_set(self : GHeap, key : Addr, val : Node) {
  let Addr(i) = key
  self.memory[i] = Some(val)
}



// 指令对应实现
//
//

fn pushglobal(self : GState, name : String) {
  let sc = self.globals[name]
  match sc {
    None => abort("pushglobal(): cant find supercombinator \(name)")
    Some(addr) => {
      self.putStack(addr)
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

fn unwind(self : GState) {
  let addr = self.pop1()
  match self.heap[addr] {
    NNum(n) => self.putStack(addr)
    NApp(a1, _) => {
      self.putStack(addr)
      self.putStack(a1)
      self.putCode(Cons(Unwind, Nil))
    }
    NGlobal(_, n, c) => {
      if length(self.stack) < n {
        abort("Unwinding with too few arguments")
      } else {
        self.putStack(addr)
        self.putCode(c)
      }
    }
    NInd(a) => {
      self.putStack(a)
      self.putCode(Cons(Unwind, Nil))
    }
    otherwise => abort("unwind() : wrong kind of node \(otherwise), address \(addr)")
  }
}

fn update(self : GState, n : Int) {
  let addr = self.pop1()
  let dst = nth(self.stack, n)
  self.heap[dst] = NInd(addr)
}