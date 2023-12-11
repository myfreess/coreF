在惰性函数式语言中，表达式以图(graph)而非树的形式存储在内存中。

为什么要这样？

看看这个程序

```haskell
square x = x * x
main = square (square 3)
```

如果我们按照一般的树形表达式来求值，表达式会被规约成

```mermaid

```

此处的`square 3`是一个未被执行的thunk，如果使用树形式，则它会被重复求值两遍。

