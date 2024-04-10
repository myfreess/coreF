type Addr Int derive(Eq, Debug, Show)

fn hash(self : Addr) -> Int {
  let Addr(i) = self
  i.hash()
}

enum Node {
  NNum(Int)
  NApp(Addr, Addr)
  NGlobal(String, Int, List[Instruction])
  NInd(Addr)
} derive (Eq, Debug, Show)

struct GHeap {
  mut objectCount : Int
  memory : Array[Option[Node]]
}

type GStats Int

let initialStat : GStats = GStats(0)

fn statInc(self : GState) -> Unit {
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
  mut dump : List[(List[Instruction], List[Addr])]
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
    // let stack = lst2str(self.stack)
    // let restcodes = lst2str(is)
    // println("current stack : \(stack)")
    // println("exec instruction \(i)")
    // println("rest instructions \(restcodes)")
    // let GStats(n) = self.stats
    // println("stat = \(n)")
    // println(" ")
      match i {
        PushGlobal(f) => self.pushglobal(f)
        PushInt(n) => self.pushint(n)
        Push(n) => self.push(n)
        MkApp => self.mkapp()
        Slide(n) => self.slide(n)
        Unwind => self.unwind()
        Update(n) => self.update(n)
        Pop(n) => { self.stack = drop(self.stack, n) }
        Alloc(n) => self.allocNodes(n)
        Eval => self.eval()
        Add => self.liftArith2(fn (x, y) { x + y})
        Sub => self.liftArith2(fn (x, y) { x - y})
        Mul => self.liftArith2(fn (x, y) { x * y})
        Div => self.liftArith2(fn (x, y) { x / y})
        Neg => self.negate()
        Eq => self.liftCmp2(fn (x, y) { x == y })
        Ne => self.liftCmp2(fn (x, y) { x != y })
        Lt => self.liftCmp2(fn (x, y) { x < y })
        Le => self.liftCmp2(fn (x, y) { x <= y })
        Gt => self.liftCmp2(fn (x, y) { x > y })
        Ge => self.liftCmp2(fn (x, y) { x >= y })
        Cond(i1, i2) => self.condition(i1, i2)
      }
      return true
    }
  }
}

fn reify(self : GState) -> Unit {
  if self.step() {
    self.reify()
  } else {
    let stack = self.stack
    match stack {
      Cons(addr, Nil) => {
        let res = self.heap[addr]
        println("result = \(res)")
      }
      _ => abort("wrong stack \(stack)")
    }  
  }
}

fn buildInitialHeap(scdefs : List[(String, Int, List[Instruction])]) -> (GHeap, RHTable[String, Addr]) {
  let heap = { objectCount : 0, memory : Array::make(10000, None) }
  let globals = RHTable::new(50)
  fn go(lst : List[(String, Int, List[Instruction])]) {
    match lst {
      Nil => ()
      Cons((name, arity, instrs), rest) => {
        let addr = heap.alloc(NGlobal(name, arity, instrs))
        globals[name] = addr
        go(rest)
      }
    }
  }
  go(scdefs)
  return (heap, globals)
}

let initialCode : List[Instruction] = List::[PushGlobal("main"), Eval]

let initialDump : List[(List[Instruction], List[Addr])] = Nil

fn putStack(self : GState, addr : Addr) -> Unit {
  self.stack = Cons(addr, self.stack)
}

fn putDump(self : GState, codes : List[Instruction], stack : List[Addr]) -> Unit {
  self.dump = Cons((codes, stack), self.dump)
}

fn putCode(self : GState, is : List[Instruction]) -> Unit {
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

/// 从 a1 : a2 : s 弹出 (a1, a2)
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

fn op_set(self : GHeap, key : Addr, val : Node) -> Unit{
  let Addr(i) = key
  self.memory[i] = Some(val)
}



// 指令对应实现
//
//

fn pushglobal(self : GState, name : String) -> Unit {
  let sc = self.globals[name]
  match sc {
    None => abort("pushglobal(): cant find supercombinator \(name)")
    Some(addr) => {
      self.putStack(addr)
    }
  }
}

fn pushint(self : GState, num : Int) -> Unit {
  let addr = self.heap.alloc(NNum(num))
  self.putStack(addr)
}

fn mkapp(self : GState) -> Unit {
  let (a1, a2) = self.pop2()
  let appaddr = self.heap.alloc(NApp(a1, a2))
  self.putStack(appaddr)
}

fn push(self : GState, offset : Int) -> Unit {
  // 将第offset + 1个地址复制到栈顶
  //    Push(n) a0 : . . . : an : s
  // => an : a0 : . . . : an : s
  let appaddr = nth(self.stack, offset)
  self.putStack(appaddr)
} 

fn slide(self : GState, n : Int) -> Unit {
  let addr = self.pop1()
  self.stack = Cons(addr, drop(self.stack, n))
}

fn rearrange(self : GState, n : Int) -> Unit {
  let appnodes = take(self.stack, n)
  let args = map(fn (addr) {
  let NApp(_, arg) = self.heap[addr]
      arg
  }, appnodes)
  self.stack = append(args, drop(appnodes, n - 1))
}

fn unwind(self : GState) -> Unit {
  let addr = self.pop1()
  match self.heap[addr] {
    NNum(_) => {
      match self.dump {
        Nil => self.putStack(addr)
        Cons((instrs, stack), restDump) => {
          // 对栈进行还原
          self.stack = stack
          self.putStack(addr)
          self.dump = restDump
          // 转回原代码执行
          self.code = instrs
        }
      }
    }
    NApp(a1, _) => {
      self.putStack(addr)
      self.putStack(a1)
      self.putCode(Cons(Unwind, Nil))
    }
    NGlobal(_, n, c) => {
      let k = length(self.stack)
      if k < n {
        match self.dump {
          Nil => abort("Unwinding with too few arguments")
          Cons((i, s), rest) => {
            // a1 : ...... : ak
            // ||
            // ak : s
            // 保留redex, 还原栈
            self.stack = append(drop(self.stack, k - 1), s)
            self.dump = rest
            self.code = i
          }
        }
      } else {
        if n != 0 {
          self.rearrange(n)
        } else {
          self.putStack(addr)
        }
        self.putCode(c)
      }
    }
    NInd(a) => {
      self.putStack(a)
      self.putCode(List::[Unwind])
    }
    otherwise => abort("unwind() : wrong kind of node \(otherwise), address \(addr)")
  }
}

fn update(self : GState, n : Int) -> Unit {
  let addr = self.pop1()
  let dst = nth(self.stack, n)
  self.heap[dst] = NInd(addr)
}

fn allocNodes(self : GState, n : Int) -> Unit {
  let dummynode : Node = NInd(Addr(-1))
  for i = 0; i < n; i = i + 1 {
    let addr = self.heap.alloc(dummynode)
    self.putStack(addr)
  }
}

fn eval(self : GState) -> Unit {
  let addr = self.pop1()
  self.putDump(self.code, self.stack)
  self.stack = List::[addr]
  self.code = List::[Unwind]
}

fn negate(self : GState) -> Unit {
  let addr = self.pop1()
  match self.heap[addr] {
    NNum(n) => {
      let addr = self.heap.alloc(NNum(-n))
      self.putStack(addr)
    }
    otherwise => {
      // 不是NNum 直接报错
      abort("negate: wrong kind of node \(otherwise), address \(addr) ")
    }
  }
}

fn condition(self : GState, i1 : List[Instruction], i2 : List[Instruction]) -> Unit {
  let addr = self.pop1()
  match self.heap[addr] {
    NNum(0) => {
      // false, 跳转i2
      self.code = append(i2, self.code)
    }
    NNum(1) => {
      // true, 跳转i1
      self.code = append(i1, self.code)
    }
    otherwise => abort("cond : \(addr) = \(otherwise)")
  }
}

fn liftArith2(self : GState, op : (Int, Int) -> Int) -> Unit {
  // 二元算术操作
  let (a1, a2) = self.pop2()
  match (self.heap[a1], self.heap[a2]) {
    (NNum(n1), NNum(n2)) => {
      let newnode = Node::NNum(op(n1, n2))
      let addr = self.heap.alloc(newnode)
      self.putStack(addr)
    }
    (node1, node2) => abort("liftArith2: \(a1) = \(node1) \(a2) = \(node2)")
  }
}

fn liftCmp2(self : GState, op : (Int, Int) -> Bool) -> Unit {
  // 二元比较操作
  let (a1, a2) = self.pop2()
  match (self.heap[a1], self.heap[a2]) {
    (NNum(n1), NNum(n2)) => {
      let flag = op(n1, n2)
      let newnode = if flag { Node::NNum(1) } else { Node::NNum(0) }
      let addr = self.heap.alloc(newnode)
      self.putStack(addr)
    }
    (node1, node2) => abort("liftCmp2: \(a1) = \(node1) \(a2) = \(node2)")
  }
}
