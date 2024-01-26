## 什么是惰性求值

`map`, `filter`这样的高阶函数是很多人接触函数式编程的第一印象(虽然它远不止这些内容)。它们简化了很多列表处理任务，但另一个问题也随之显现，就是这样的高阶函数套太多性能会比较差(主要原因是需要多次遍历列表)。

一些人想到，可以让编译器利用一些高阶函数上的规律优化代码，例如可以把`map(f, map(g, list))`改写成

```rust
map(fn (x) { f(g(x)) }, list)
```

这当然很好，但这样的优化措施有其局限性，在面对更复杂的情况时就不总是能合并函数调用了。把所有处理都写在一个函数里可以避免重复遍历列表，但是可读性不好也不方便改。有没有相对折中一点的方案呢？

惰性求值就是一种能够在这种场景下一定程度减少不必要成本的技术。它可以只在某种数据结构内部提供(例如java8增加的Stream类型), 也可以将整个语言设计成惰性的(这一思路的代表者是上世纪80年代的Miranda语言以及后来的Haskell与Clean语言)。

## 一种惰性求值语言及其抽象语法树



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

## 一些约定

接下来我们要讨论的是图规约如何进行。在此之前，需要预先交代一些名词与基本事实。

+ `mul`这样的东西是预先定义好的，称作*Built-in primitive*

+ 对一个表达式进行求值(当然是惰性的)并对它在图中对应的节点进行原地更新，称为规约。

+ `(square 3)`是一个可规约表达式(reducible expression，一般缩写为redex), 它可以被规约为`(mul 3 3)`。 `(mul 3 3)`也是一个redex，但是它和`(square 3)`是两种不同的redex(因为`square`是自定义的超组合子，而`mul`是实现内置的)。

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

**第二步：规约**

**第三步：更新**

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
```

## 各指令对应作用



## 将超组合子编译为指令序列

## 运行G-Machine

## 垃圾收集