## 追踪上下文

回顾一下我们之前实现primitive的方法：

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

这样的实现引入了很多`Eval`指令，但它们未必总是用得上。例如：

```clojure
(add 3 (mul 4 5))
```

`add`的两个参数在执行`Eval`之前就已经是WHNF, 这里的`Eval`指令是多余的。

一种可行的优化方法是在编译表达式时注意其上下文。例如，add需要它的参数被求值成WHNF，那么它的参数在编译时就处于严格(Strict)上下文中。通过这种方式，我们可以识别出一部分可以安全地按照严格求值进行编译的表达式(仅有一部分)

我们用函数`compileE`实现这种严格求值上下文下的编译，它所生成的指令可以保证*栈顶地址指向的值一定是一个WHNF*。

首先对于默认分支，我们仅仅在`compileC`的结果后面加一条`Eval`指令

```rust
append(compileC(self, env), List::[Eval])
```

常数则直接push

```rust
Num(n) => List::[PushInt(n)]
```

对于`let/letrec`表达式，之前特意设计的`compileLet`和`compileLetrec`便起到用处了，编译一个严格上下文中的`let/letrec`表达式只需要用`compileE`编译其主表达式即可

```rust
Let(rec, defs, e) => {
  if rec {
    compileLetrec(compileE, defs, e, env)
  } else {
    compileLet(compileE, defs, e, env)
  }
}
```

`if`和`negate`的参数数量分别为3、1， 需要单独处理。

```rust
App(App(App(Var("if"), b), e1), e2) => {
  let condition = compileE(b, env)
  let branch1 = compileE(e1, env)
  let branch2 = compileE(e2, env)
  append(condition, List::[Cond(branch1, branch2)])
}
App(Var("negate"), e) => {
  append(compileE(e, env), List::[Neg])
}
```

基础的二元运算则可以通过查表统一处理, 首先构建一个叫做`builtinOpS`的哈希表，它允许我们通过primitive的名字查询对应指令。

```rust
let builtinOpS : RHTable[String, Instruction] = {
  let table : RHTable[String, Instruction] = RHTable::new(50)
  table["add"] = Add 
  table["mul"] = Mul
  table["sub"] = Sub
  table["div"] = Div
  table["eq"]  = Eq
  table["neq"] = Ne
  table["ge"] = Ge 
  table["gt"] = Gt
  table["le"] = Le
  table["lt"] = Lt
  table
}
```

其余处理则没有太多区别。

```rust
App(App(Var(op), e0), e1) => {
  match builtinOpS[op] {
    None => append(compileC(self, env), List::[Eval]) // 不是primitive op, 走默认分支
    Some(instr) => {
      let code1 = compileE(e1, env)
      let code0 = compileE(e0, argOffset(1, env))
      append(code1, append(code0, List::[instr]))
    }
  }
}
```

大功告成了吗？好像是的，不过，除了整数，其实还有另外一种WHNF: 偏应用(partial application)的函数

所谓偏应用，就是指参数数量不足。这种情况常见于高阶函数，例如

```clojure
(map (add 1) listofnumbers)
```

这里的`(add 1)`就是一个偏应用.

要让新的编译策略产生的代码不出问题，我们还得修改`Unwind`指令关于`NGlobal`分支的实现。在参数数量不足且dump中有保存的栈时，只保留原本的redex并且还原栈。

```rust
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
    ......
  }
}
```

## 自定义数据结构

## 尾声

惰性求值这一技术可以减少运行时的重复运算，与此同时它也引入了一些新的问题。这些问题包括：

+ 臭名昭著的副作用顺序问题。

+ 冗余节点过多。一些根本不会共享的计算也要把结果放到堆上

惰性求值语言的代表haskell对于副作用顺序给出了一个毁誉参半的解决方案：Monad。该方案对急切求值的语言也有一定价值，但网络上关于它的教程往往在介绍此概念时过分强调其数学背景，对如何使用反而疏于讲解。笔者建议不必在这方面花费过多时间。

SPJ设计的Spineless G-Machine改进了冗余节点过多的问题，而作为其后继的STG统一了不同种类节点的数据布局。

2004年，GHC的几位设计者发现以前这种参数入栈然后进入某个函数的调用模型(push enter)反而不如将责任交给调用者的eval apply模型，他们发表了一篇论文Making a Fast Curry: Push/Enter vs. Eval/Apply for Higher-order Languages。