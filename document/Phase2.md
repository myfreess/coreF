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
fn rearrange(self : GState, n : Int) {
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
fn push(self : GState, offset : Int) {
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
..............
```

所以我们还需要一个新指令用来清理这些不再需要的地址，它叫做Slide(滑动)。顾名思义，`Slide(n)`的作用是跳过第一个地址，删除紧随其后的N个地址

```rust
fn slide(self : GState, n : Int) {
  let addr = self.pop1()
  self.stack = Cons(addr, drop(self.stack, n))
}
```

现在我们可以编译let了。我们将编译本地变量对应表达式的任务`compileC`函数。然后遍历变量定义的列表(`defs`), 按顺序编译并更新对应偏移量。最后使用传入的`comp`函数编译主表达式，并且加上`Slide`指令清理无用地址。

> 此处编译主表达式使用传入函数是为了方便添加后续特性时便于复用

```rust
fn compileLet(comp : (RawExpr[String], List[(String, Int)]) -> List[Instruction], defs : List[(String, RawExpr[String])], expr : RawExpr[String], env : List[(String, Int)]) -> List[Instruction] {
  let mut codes : List[Instruction] = Nil
  let mut env = env
  loop defs {
    Nil => ()
    Cons((name, expr), rest) => {
      codes = append(codes, compileC(expr, env))
      // 更新偏移量并加入name所对应的本地变量的偏移量
      env = Cons((name, 0), argOffset(1, env))
      continue(rest)
    }
  }
  append(codes, append(comp(expr, env), Cons(Slide(length(defs)), Nil)))
}
```

而letrec对应的语义要复杂一些 - 它允许表达式内的N个变量互相引用，所以需要预先申请N个地址并放到栈上。我们需要一个新指令：`Alloc(N)`, 它会预分配N个`NInd`节点并将地址依次入栈。这些间接节点里的地址是小于零的，只起到占位置的作用。

```rust
fn allocNodes(self : GState, n : Int) {
  let dummynode : Node = NInd(Addr(-1))
  let mut i = 0
  while i < n, i = i + 1 {
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
  let mut env = env
  loop defs {
    Nil => ()
    Cons((name, _), rest) => {
      env = Cons((name, 0), argOffset(1, env))
      continue(rest)
    }
  }
  let n = length(defs)
  fn compileDefs(defs : List[(String, RawExpr[String])], offset : Int) -> List[Instruction] {
    match defs {
      Nil => append(comp(expr, env), Cons(Slide(n), Nil))
      Cons((_, expr), rest) => append(compileC(expr, env), Cons(Update(offset),  compileDefs(rest, offset - 1)))
    }
  }
  Cons(Alloc(n), compileDefs(defs, n - 1))
}
```

## 加入primitive

## 自定义数据结构

## 尾声

惰性求值这一技术可以减少运行时的重复运算，与此同时它也引入了一些新的问题。这些问题包括：

+ 臭名昭著的副作用顺序问题。

+ 冗余节点过多。一些根本不会共享的计算也要把结果放到堆上

惰性求值语言的代表haskell对于副作用顺序给出了一个毁誉参半的解决方案：Monad。该方案对急切求值的语言也有一定价值，但网络上关于它的教程往往在介绍此概念时过分强调其数学背景，对如何使用反而疏于讲解。笔者建议不必在这方面花费过多时间。

SPJ设计的Spineless G-Machine改进了冗余节点过多的问题，而作为其后继的STG统一了不同种类节点的数据布局。

2004年，GHC的几位设计者发现以前这种参数入栈然后进入某个函数的调用模型(push enter)反而不如将责任交给调用者的eval apply模型，他们发表了一篇论文Making a Fast Curry: Push/Enter vs. Eval/Apply for Higher-order Languages。