`map`, `filter`这样的高阶函数是很多人接触函数式编程的第一印象(虽然它远不止这些内容)。它们简化了很多列表处理任务，但另一个问题也随之显现，就是这样的高阶函数套太多性能会比较差(主要原因是需要多次遍历列表)。

一些人想到，可以让编译器利用一些高阶函数上的规律优化代码，例如可以把`map(f, map(g, list))`改写成

```rust
map(fn (x) { f(g(x)) }, list)
```

这当然很好，但这样的优化措施有其局限性，在面对更复杂的情况时就不总是能合并函数调用了。把所有处理都写在一个函数里可以避免重复遍历列表，但是可读性不好也不方便改。有没有相对折中一点的方案呢？

惰性求值就是一种能够在这种场景下一定程度减少不必要成本的技术。它可以只在某种数据结构内部提供(例如java8增加的Stream类型，以及更早的Scheme语言中的stream), 也可以将整个语言设计成惰性的(这一思路的代表者是上世纪80年代的Miranda语言以及后来的Haskell与Clean语言)。

让我们先看看惰性列表(`Stream`)如何在这样的情况下避免多次遍历。

## 惰性列表实现

首先写出其类型定义

```rust
enum Stream[T] {
  Empty
  Cons(T, () -> Stream[T])
}
```

和`List[T]`只有一处有真正的差别：`Cons`中存放余下列表的地方换成了一个无参数函数(按行话来讲叫*thunk*)。这就是惰性求值的简单实现：用一个thunk把不想现在就马上算出来的东西包裹起来。

我们还需要一个函数把常规列表转换成惰性列表

```rust
fn Stream::fromList[T](l : List[T]) -> Stream[T] {
  match l {
    Nil => Empty
    Cons(x, xs) => Cons(x, fn () { Stream::fromList(xs) })
  }
}
```

这个函数不需要遍历整个列表来将它转化为`Stream`, 对于当前不急着要结果的运算(这里是`Stream::fromList(xs)`), 我们直接将其包裹在thunk里返回。接下来的`map`函数也会采用这个思路(不过这里的`xs`已经是thunk了)。

```rust
fn stream_map[X, Y](self : Stream[X], f : (X) -> Y) -> Stream[Y] {
  match self {
    Empty => Empty
    Cons(x, xs) => Cons(f(x), fn () { xs().stream_map(f) })
  }
} 
```

`take`函数负责执行运算，它可以按需取出n个元素。

```rust
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
```

使用thunk实现的惰性数据结构简单易用，也很好地解决了上文中的问题。这种方法需要用户明确指出代码的某处应该延迟计算，而惰性语言的策略则要激进地多：它默认对所有用户定义的函数使用延迟计算策略！我们将在下文中展示一种简单的惰性函数式语言的极小实现，并对其背后的理论模型稍做介绍。

## 一种惰性求值语言及其抽象语法树

本文所用的示例是一个刻意弄得跟clojure(这是一种lisp方言)有点像的惰性求值语言，这样做是因为可以在markdown中使用clojure语言的语法高亮。

constant applicative forms = 无参数sc

## 为什么是图

在惰性函数式语言中，表达式以图(graph)而非树的形式存储在内存中。

为什么要这样？

看看这个程序

```clojure
(defn square[x]  (mul x x))
(defn main[] (square (square 3)))
```

如果我们按照一般的树形表达式来求值，表达式会被规约成

```clojure
(mul (square 3) (square 3))
```

则`(square 3)`会被重复求值两遍。这绝对不是那些选择惰性求值的人想要的。

为了展示得更清晰一点，我们用MoonBit代码来做个不大恰当的类比.

```rust
fn square(thunk : () -> Int) -> Int {
  thunk() * thunk()
}
```

用图来表示程序是为了共享计算结果，避免重复计算(要达到这个目的还需要在实现图规约算法时实现为原地更新)。关于原地更新，我们仍然用MoonBit代码模拟一下看看

```rust
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
      self.data = Done(value) // 原地更新
      value
    }
    Done(value) => value
  }
}

fn square(x : LazyRef[Int]) -> Int {
  x.extract() * x.extract()
}
```

无论左右两侧哪一边的`extract`方法先执行，它都会更新引用的可变字段并将内容替换为计算结果。那么第二次执行`extract`方法就不必再算一遍了。

## 一些约定

接下来我们要讨论的是图规约如何进行。在此之前，需要预先交代一些名词与基本事实。仍然使用这个程序作为例子：

```clojure
(defn square[x]  (mul x x))
(defn main[] (square (square 3)))
```

+ `mul`这样的东西是预先定义好的，称作*Built-in primitive*

+ 对一个表达式进行求值(当然是惰性的)并对它在图中对应的节点进行原地更新，称为规约。

+ `(square 3)`是一个可规约表达式(reducible expression，一般缩写为redex), 由`square`和它的一个参数组成. 它可以被规约为`(mul 3 3)`。 `(mul 3 3)`也是一个redex，但是它和`(square 3)`是两种不同的redex(因为`square`是自定义的超组合子，而`mul`是实现内置的primitive)。

+ `(mul 3 3)`的规约结果是表达式`9`, `9`没办法再进行规约，这种无法继续规约的基础表达式称为Normal form.

+ 一个表达式中可能存在多个子表达式(如`(mul (add 3 5) (mul 7 9))`), 在这种情况下表达式的规约顺序是很重要的 - 一些程序只在特定的规约顺序下停机。

+ 有个特殊的规约顺序永远选择最外层的redex进行规约，这叫做*normal order reduction*。下文也将统一采用这种规约顺序。

那么，可以用这样的伪代码描述图规约：

```
如果存在可规约表达式 {
    选择最外层的可规约表达式
    规约
    用规约结果更新图
}
```

这还是有些过分抽象了，让我们找几个例子来演示一下如何在纸面上执行规约。

**第一步：找出下一个redex**

整个程序的执行从`main`开始

```clojure
(defn square[x]  (mul x x))
(defn main[] (add 33 (square 3)))
```

main本身是一个CAF - 这是最简单的一种redex，我们执行替换，则当前需要处理的表达式为

```clojure
(add 33 (square 3))
```

根据找最外层redex的原则，我们似乎马上就找到了`add`和它的两个参数共同构成的redex(暂且这样认为)

但是稍等！由于默认柯里化的存在，这个表达式对应的抽象语法树实际上是多个`App`节点嵌套构成的，大致上是这样(为了方便阅读此处有简化)

```rust
App(App(add, 33), square3)
```

这个从`add`到最外层`App`节点的链式结构叫做`Spine`(英文中的"脊柱")。

回过头来检查一下，add是一个内部定义的`primitive`, 但由于它的第二个参数`(square 3)`不是normal form，我们没办法规约它(把一个未求值的表达式和一个整数相加，有点太荒谬了)。所以还不能说我们找到的`(add 33 (square 3))`是个redex，它只能说是最外层的函数应用罢了，为了规约它，必须先规约`(square 3)`。

**第二步：规约**

`square`是一个用户定义的超组合子，所以对`(square 3)`进行规约只需要做参数替换即可。

不过，假如某个redex中参数的数量少于该超组合子所需的数量 - 这种场景常见于高阶函数，举个例子，要让某个列表中的所有整数全部扩大三倍

```clojure
(map (mul 3) list-of-int)
```

这里的`(mul 3)`因为参数数量不够所以没法作为redex处理，它是一个`weak head normal form`(一般缩写为WHNF), 在这种情况下即使它的子表达式中包含redex，也不需要做任何事。

**第三步：更新**

这一步只影响执行效率，纸面推导不做即可。

这些操作在纸面上很好完成(在代码量不超过半张纸的时候)，但是当我们把目光转向计算机，具体该怎样把这些步骤转化成可执行的代码呢？

为了解答这个问题，探索惰性求值的程序语言界先驱们提出了多种对惰性求值进行建模的**抽象机器(abstract machine)**, 这其中包括

+ G-Machine
+ Three Instruction Machine
+ ABC Machine(它被Clean语言使用)
+ Spineless Tagless G-Machine(缩写为STG, 被今天的Haskell语言使用)

它们是一种用于指导编译器实现的执行模型，需要注意的是，比起今天所流行的各种虚拟机(例如JVM)，抽象机器更像编译器的中间表示(IR)。以haskell的编译器GHC为例，它在生成STG代码后并不会将它送给一个解释器直接执行，而是根据所选的后端进一步转换为LLVM、C代码或者机器码。

为了简化实现，本文将直接用MoonBit语言编写一个G-Machine指令的解释器，从一个极小化的例子开始一步步地加入更多特性。

## G-Machine概览

G-Machine首先是一种状态机，它的状态包括：

+ 堆(Heap), 这是存放表达式图和超组合子对应指令序列的地方。它的基本单元是图节点。

```rust
type Addr Int derive(Eq, Show) // 使用type关键字包装一个地址类型

enum Node { // 图节点用一个枚举类型描述
  NNum(Int)
  NApp(Addr, Addr) // 应用节点
  NGlobal(Int, List[Instruction]) // 存放超组合子的参数数量和对应指令序列
  NInd(Addr) // Indirection节点, 实现惰性求值的关键一环
} derive (Eq)

struct GHeap { // 堆使用数组，数组中内容为None的空间是可使用的空闲内存
  mut objectCount : Int
  memory : Array[Option[Node]]
}

// 给节点分配堆空间
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
```

+ 栈，栈内只存放指向堆的地址。简单的实现用`List[Addr]`即可

+ 全局表，它是一个记录着超组合子名字(包括预定义的和用户定义的)和对应`NGlobal`节点地址的映射表。笔者选择用RobinHood哈希表实现。

+ 当前所需执行的代码序列

+ 执行状况统计数据，比较简单的实现是计算执行了多少条指令。

```rust
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
```

整个状态使用类型`GState`表示

```rust
struct GState {
  stack : List[Addr]
  heap : GHeap
  globals : RHTable[String, Addr]
  code : List[Instruction]
  stats : GStats
}

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
```

现在我们可以回顾前文中在纸面上推导的图规约算法一一对应到这台抽象机器了：

+ 机器的初始状态下，所有编译好的超组合子都已经被放到堆上的NGlobal节点中，而此时G-Machine中的当前代码序列只包含两条指令，第一条将main的对应节点地址放到栈上，第二条将main的对应指令序列加载到当前指令序列。

+ main的对应指令序列会在堆上分配节点并装入相应数据，最后在堆内存中构造出一个图，这个过程称为main的"实例化"。构造完毕后这个图的入口地址会被放到栈顶。

+ 完成实例化之后需要做收尾工作，即更新图节点(由于main没有参数，所以不必清理栈中的残留无用地址)并寻找下一个redex。

这些工作都有对应的指令实现。

## 各指令对应作用

目前这个极度简化的G-Machine共有7条指令 

```rust
enum Instruction {
  Unwind
  PushGlobal(String)
  PushInt(Int)
  PushArg(Int)
  MkApp
  Update(Int)
  Pop(Int)
} derive (Eq, Debug, Show)
```

`PushInt`指令最为简单，它在堆上分配一个`NNum`节点，并将它的地址入栈。

```rust
fn pushint(self : GState, num : Int) {
  let addr = self.heap.alloc(NNum(num))
  self.putStack(addr)
}
```

`PushGlobal`指令从全局表中找到指定超组合子的地址，然后将地址入栈。

```rust
fn pushglobal(self : GState, name : String) {
  let sc = self.globals[name]
  match sc {
    None => abort("pushglobal(): cant find supercombinator \(name)")
    Some(addr) => {
      self.putStack(addr)
    }
  }
}
```

`PushArg`则复杂一些，它对栈内的地址布局有特定要求：第一个地址应该指向超组合子节点，紧随其后的n个地址则指向N个`NApp`节点。而`PushArg`会取到第`offset + 1`个参数。

```rust
fn pusharg(self : GState, offset : Int) {
  // 跳过首个超组合子节点
  // 访问第offset + 1个NApp节点
  let appaddr = nth(self.stack, offset + 1)
  let arg = match self.heap[appaddr] {
    NApp(_, arg) => arg
    otherwise => abort("pusharg: stack offset \(offset) address \(appaddr) node \(otherwise), not a applicative node")
  }
  self.putStack(arg)
} 
```

`MkApp`指令从栈顶取出两个地址，然后构造一个`NApp`节点并将地址入栈。

```rust
fn mkapp(self : GState) {
  let (a1, a2) = self.pop2()
  let appaddr = self.heap.alloc(NApp(a1, a2))
  self.putStack(appaddr)
}
```

`Update`指令假设栈内第一个地址指向当前redex求值结果，跳过紧随其后的超组合子节点地址，把第N个`NApp`节点替换为一个指向求值结果的间接节点。如果当前redex是CAF，那就直接把它在堆上的`NGlobal`节点替换掉. 从这里也能看出来，为什么在惰性函数式语言里无参数函数和普通变量没有太多区别。

```rust
fn update(self : GState, n : Int) {
  let addr = self.pop1()
  let dst = nth(self.stack, n)
  self.heap[dst] = NInd(addr)
}
```

`Unwind`指令是G-Machine中类似于求值循环一样的东西，它有好几个分支条件，根据栈顶地址对应节点的种类进行判断

+ `Nnum`, 什么也不做
+ `NApp`, 将左侧地址入栈，再次`Unwind`
+ `NGlobal`, 在栈内有足够参数的情况下，将该超组合子加载到当前代码
+ `NInd`, 将该间接节点内地址入栈，再次`Unwind`·

```rust
fn unwind(self : GState) {
  let addr = self.pop1()
  match self.heap[addr] {
    NNum(_) => self.putStack(addr)
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
```

`Pop`指令弹出n个地址，就不用函数单独实现了。

## 将超组合子编译为指令序列

在G-Machine概览一节，我们大致描述了一下编译后的超组合子具有何种行为，现在可以精确地描述超组合子的编译了。

首先，在一个超组合子编译出的指令序列执行前，栈内一定已经存在这样一些地址：

+ 最顶部的地址指向一个`NGlobal`节点(超组合子本身)

+ 紧随其后的N个地址(N是该超组合子的参数数量)则指向一系列的App节点 - 正好对应到一个redex的spine，栈最底层的地址指向表达式最外层的App节点，其余以此类推。

在编译超组合子时，我们需要维护一个环境，这个环境允许我们在编译过程中通过参数的名字找到参数在栈中的相对位置。此外，由于完成超组合子的实例化之后需要清理掉前面的N+1个地址，还需要传入参数的个数N.

> 此处所说的“参数”都是指向堆上App节点的地址，通过pusharg指令可以访问到真正的参数地址

```rust
fn compileSC(self : ScDef[String]) -> (String, Int, List[Instruction]) {
  let name = self.name
  let body = self.body
  let mut arity = 0
  fn gen_env(i : Int, args : List[String]) -> List[(String, Int)] {
    match args {
      Nil => {
        arity = i
        return Nil
      }
      Cons(s, ss) => Cons((s, i), gen_env(i + 1, ss))
    }
  }
  let env = gen_env(0, self.args)
  (name, arity, compileR(body, env, arity))
}
```

`compileR`函数通过调用`compileC`函数来生成对超组合子进行实例化的代码，并在后面加上三条指令。这三条指令各自的工作是：

+ `Update(N)`将堆中原本的redex更新为一个`NInd`节点，这个间接节点则指向刚刚实例化出来的超组合子

+ `Pop(N)`清理栈中已经无用的地址

+ `Unwind`寻找redex开始下一次规约

```rust
fn compileR(self : RawExpr[String], env : List[(String, Int)], arity : Int) -> List[Instruction] {
  append(compileC(self, env), Cons(Update(arity), Cons(Pop(arity), Cons(Unwind, Nil))))
}
```

在编译超组合子的定义时使用比较粗糙的方式：一个变量如果不是参数，就当成其他超组合子(写错了会导致运行时错误)。对于函数应用，先编译右侧，然后将环境中所有参数对应的偏移量加一，再编译左侧，最后加上`MkApp`指令。

```rust
fn compileC(self : RawExpr[String], env : List[(String, Int)]) -> List[Instruction] {
  match self {
    Var(s) => {
      match lookupENV(env, s) {
        None => Cons(PushGlobal(s), Nil)
        Some(n) => Cons(PushArg(n), Nil)
      }
    }
    Num(n) => Cons(PushInt(n), Nil)
    App(e1, e2) => {
      append(compileC(e2, env), append(compileC(e1, argOffset(1, env)), Cons(MkApp, Nil)))
    }
    _ => abort("not support yet")
  }
}
```

## 运行G-Machine

编译完毕的超组合子还需要放到堆上(以及把地址放到全局表里), 递归处理即可。

```rust
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
```

定义函数step，它将G-Machine的状态更新一步，如果已经到达最终状态就返回false

```rust
fn step(self : GState) -> Bool {
  match self.code {
    Nil => { return false }
    Cons(i, is) => {
      self.code = is
      self.statInc()
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
```

另外定义函数reify不断执行step直到最终状态

```rust
fn reify(self : GState) {
  if self.step() {
    self.reify()
  } else {
    let stack = self.stack
    match stack {
      Cons(addr, Nil) => {
        let res = self.heap[addr]
        println("\(res)")
      }
      _ => abort("wrong stack \(stack)")
    }  
  }
}
```

对上文中的各部分进行组装

```rust
fn run(codes : List[String]) {
  fn parse_then_compile(code : String) -> (String, Int, List[Instruction]) {
    let code = TokenStream::new(code)
    let code = parseSC(code)
    let code = compileSC(code)
    return code
  }
  let codes = append(map(parse_then_compile, codes), map(compileSC, preludeDefs))
  let (heap, globals) = buildInitialHeap(codes)
  let initialState : GState = {
    heap : heap,
    stack : Nil,
    code : initialCode,
    globals : globals,
    stats : initialStat
  }
  initialState.reify()
}
```

## 尾声

我们现在所构建的G-Machine特性过少，很难运行一点稍微像样的程序。在下一篇文中，我们将一步步加入primitive和自定义数据结构等特性，并在结尾介绍G-Machine之后的惰性求值技术。