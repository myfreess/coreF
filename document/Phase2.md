本期文章为在MoonBit中实现惰性求值的第二篇。在第一篇中，我们了解了惰性求值的用途以及惰性求值的一种典型抽象机器G-Machine, 并实现了一些基础的G-Machine指令。在这一篇文章中，我们将进一步扩展上篇文章中的G-Machine实现，使其支持`let`表达式与基础的算术、比较等操作。

## let表达式

coref中的let表达式和MoonBit稍有不同，一个let表达式可以创建多个变量，但只能在受限的范围内使用。下为一例：

```rust
{
  let x = n + m
  let y = x + 42
  x * y
}
```

等价的coref表达式是

```clojure
(let ([x (add n m)]
      [y (add x 42)])
  (mul x y)) ;; 只能在let内部使用xy
```

需要注意的是，coref的let表达式也是需要按顺序来的，比如下面这么写就不行：

```clojure
(let ([y (add x 42)]
      [x (add n m)])
  (mul x y))
```

letrec相比于let就要复杂一些，它允许所定义的本地变量互相引用，而不用考虑变量定义的顺序。

在实现let(以及复杂一些的letrec)之前，首先需要变更一下目前的参数传递方式。let创建的本地变量从直觉上应该和参数用同样的方式访问，但是let定义的本地变量没有对应的`NApp`节点，所以我们需要在调用超组合子之前对栈内参数进行调整。

调整步骤在`Unwind`指令的实现中进行。如果该超组合子无参数，则和原先的unwind无区别。在有参数时，则需要丢弃顶部的超组合子节点地址，然后调用`rearrange`函数。

```rust
fn rearrange(self : GState, n : Int) -> Unit {
  let appnodes = take(self.stack, n)
  let args = map(fn (addr) {
  let NApp(_, arg) = self.heap[addr]
      arg
  }, appnodes)
  self.stack = append(args, drop(appnodes, n - 1))
}
```

`rearrange`函数假设栈前面的N个地址指向一系列`NApp`节点，它保留最底部的一个(当作Redex更新用)，清理掉上面N-1个地址，然后放上N个直接指向参数的地址。

在这之后使用参数和本地变量也可以用同一条命令实现了，将`PushArg`指令改为更通用的`Push`指令。

```rust
fn push(self : GState, offset : Int) -> Unit {
  // 将第offset + 1个地址复制到栈顶
  //    Push(n) a0 : . . . : an : s
  // => an : a0 : . . . : an : s
  let appaddr = nth(self.stack, offset)
  self.putStack(appaddr)
}
```

接下来的问题是，我们还需要一个东西做收尾工作，请看这样的一个表达式

```clojure
(let ([x1 e1]
      [x2 e2])
  expr)
```

在表达式`expr`对应的图构建好之后，栈中还残留着指向e1, e2的地址(分别对应变量x1 x2), 如下所示(栈从下往上增长)

```
<指向expr的地址>
      |
<指向x2的地址>
      |
<指向x1的地址>
      |
...余下的栈...
```

所以我们还需要一个新指令用来清理这些不再需要的地址，它叫做Slide(滑动)。顾名思义，`Slide(n)`的作用是跳过第一个地址，删除紧随其后的N个地址

```rust
fn slide(self : GState, n : Int) -> Unit {
  let addr = self.pop1()
  self.stack = Cons(addr, drop(self.stack, n))
}
```

现在我们可以编译let了。我们将编译本地变量对应表达式的任务`compileC`函数。然后遍历变量定义的列表(`defs`), 按顺序编译并更新对应偏移量。最后使用传入的`comp`函数编译主表达式，并且加上`Slide`指令清理无用地址。

> 此处编译主表达式使用传入函数是为了方便添加后续特性时便于复用

```rust
fn compileLet(comp : (RawExpr[String], List[(String, Int)]) -> List[Instruction], defs : List[(String, RawExpr[String])], expr : RawExpr[String], env : List[(String, Int)]) -> List[Instruction] {
  let (env, codes) = loop env, List::Nil, defs {
    env, acc, Nil => (env, acc)
    env, acc, Cons((name, expr), rest) => {
      let code = compileC(expr, env)
      // 更新偏移量并加入name所对应的本地变量的偏移量
      let env = List::Cons((name, 0), argOffset(1, env))
      continue env, append(acc, code), rest
    }
  }
  append(codes, append(comp(expr, env), List::[Slide(length(defs))]))
}
```

而letrec对应的语义要复杂一些 - 它允许表达式内的N个变量互相引用，所以需要预先申请N个地址并放到栈上。我们需要一个新指令：`Alloc(N)`, 它会预分配N个`NInd`节点并将地址依次入栈。这些间接节点里的地址是小于零的，只起到占位置的作用。

```rust
fn allocNodes(self : GState, n : Int) -> Unit {
  let dummynode : Node = NInd(Addr(-1))
  for i = 0; i < n; i = i + 1 {
    let addr = self.heap.alloc(dummynode)
    self.putStack(addr)
  }
}
```

编译letrec的步骤与let相似：

+ 首先使用`Alloc(n)`申请N个地址
+ 用`loop`表达式构建出完整的环境
+ 编译`defs`中的本地变量，每编译完一个都用`Update`指令将结果更新到预分配的地址上
+ 编译主表达式并用`Slide`指令清理现场

```rust
fn compileLetrec(comp : (RawExpr[String], List[(String, Int)]) -> List[Instruction], defs : List[(String, RawExpr[String])], expr : RawExpr[String], env : List[(String, Int)]) -> List[Instruction] {
  let env = loop env, defs {
    env, Nil => env
    env, Cons((name, _), rest) => {
      let env = List::Cons((name, 0), argOffset(1, env))
      continue env, rest
    }
  }
  let n = length(defs)
  fn compileDefs(defs : List[(String, RawExpr[String])], offset : Int) -> List[Instruction] {
    match defs {
      Nil => append(comp(expr, env), List::[Slide(n)])
      Cons((_, expr), rest) => append(compileC(expr, env), Cons(Update(offset), compileDefs(rest, offset - 1)))
    }
  }
  Cons(Alloc(n), compileDefs(defs, n - 1))
}
```

## 加入primitive

从这一步开始，我们终于可以做算术，比较数字大小，判断两个数是否相等这种基本的整数操作了。首先修改`Instruction`类型，加入相关指令

```rust
  Add
  Sub
  Mul
  Div 
  Neg
  Eq // ==
  Ne // !=
  Lt // <
  Le // <=
  Gt // >
  Ge // >=
  Cond(List[Instruction], List[Instruction])
```

初看起来实现这些指令很简单，以Add为例，只要弹出两个栈顶地址，从堆内存中取出对应的数，执行对应操作，再把结果的地址压进栈里

```rust
fn add(self : GState) -> Unit {
  let (a1, a2) = self.pop2() // 弹出两个栈顶地址
  match (self.heap[a1], self.heap[a2]) {
    (NNum(n1), NNum(n2)) => {
      let newnode = Node::NNum(n1 + n2)
      let addr = self.heap.alloc(newnode)
      self.putStack(addr)      
    }
    ......
  }
}
```

但是下一步我们需要面对一个问题：这是一个惰性求值语言，add的参数很可能还未进行计算(也就是说，不是`NNum`节点)。我们还需要一条指令，它应该能够强迫某个未进行的计算给出结果，或者永不停止计算。我们叫它`Eval`(Evaluation的缩写)。

> 用行话来讲，所谓的计算结果应该称之为Weak Head Normal Form(WHNF)

与此同时，我们还需要更改`GState`的结构，加入一个叫`dump`的状态。它的类型是`List[(List[Instruction], List[Addr])]`, `Eval`和`Unwind`指令会用到它。

`Eval`指令的实现并不复杂：

+ 首先弹出栈顶地址

+ 然后保存当前还没执行的指令序列和栈(保存方式就是放到dump里)

+ 清空当前栈并放入之前保存的地址

+ 清空当前指令序列，放入指令`Unwind`

> 这和严格求值语言中保存调用者上下文的处理很像，不过实用的实现会采取更高效的方法

```rust
fn eval(self : GState) -> Unit {
  let addr = self.pop1()
  self.putDump(self.code, self.stack)
  self.stack = List::[addr]
  self.code = List::[Unwind]
}
```

这个简单的定义需要修改`Unwind`指令，当`Unwind`在`NNum`分支发现存在可恢复的上下文时(`dump`不为空)进行复原。

```rust
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
    ......
  }
}
```

接下来需要的是实现算术与比较指令，我们用两个函数来简化形式统一的二元运算。比较指令的结果是布尔值，为了简化实现直接用数字代替，0为`false`, 1为`true`.

```rust
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

// 取反单独实现一下
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
```

最后实现分支：

```rust
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
```

编译部分不用过多调整，只需要加入一些预定义程序

```rust
let compiledPrimitives : List[(String, Int, List[Instruction])] = List::[
  // 算术
  ("add", 2, List::[Push(1), Eval, Push(1), Eval, Add, Update(2), Pop(2), Unwind]),
  ("sub", 2, List::[Push(1), Eval, Push(1), Eval, Sub, Update(2), Pop(2), Unwind]),
  ("mul", 2, List::[Push(1), Eval, Push(1), Eval, Mul, Update(2), Pop(2), Unwind]),
  ("div", 2, List::[Push(1), Eval, Push(1), Eval, Div, Update(2), Pop(2), Unwind]),
  // 比较
  ("eq",  2, List::[Push(1), Eval, Push(1), Eval, Eq,  Update(2), Pop(2), Unwind]),
  ("neq", 2, List::[Push(1), Eval, Push(1), Eval, Ne,  Update(2), Pop(2), Unwind]),
  ("ge",  2, List::[Push(1), Eval, Push(1), Eval, Ge,  Update(2), Pop(2), Unwind]),
  ("gt",  2, List::[Push(1), Eval, Push(1), Eval, Gt,  Update(2), Pop(2), Unwind]),
  ("le",  2, List::[Push(1), Eval, Push(1), Eval, Le,  Update(2), Pop(2), Unwind]),
  ("lt",  2, List::[Push(1), Eval, Push(1), Eval, Lt,  Update(2), Pop(2), Unwind]),
  // 杂项
  ("negate", 1, List::[Push(0), Eval, Neg, Update(1), Pop(1), Unwind]),
  ("if",     3,  List::[Push(0), Eval, Cond(List::[Push(1)], List::[Push(2)]), Update(3), Pop(3), Unwind])
]
```

以及修改初始的指令序列

```rust
let initialCode : List[Instruction] = List::[PushGlobal("main"), Eval]
```

## 尾声

下一期文章中，我们将改进针对primitive的代码生成，以及添加对数据结构的支持