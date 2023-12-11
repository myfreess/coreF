## 语法设计

使用Sexpr, 参考Clojure

```
program -> sc1 ...... scn

sc -> (defn var[var1 ... varn] expr)

expr -> (expr aexpr1 ... aexpr2) // 应用
     |  ($let (defns) expr)
     |  ($letrec (defns) expr)
     |  ($case expr alts)
     |  ($fn[var1 ... varn] expr)
     |  aexpr

aexpr -> var
      |  num
      |  (Pack num num) // Constructor

defns -> defn1 ... defnn
defn -> [var expr]

alts -> alt1 ... altn
alt -> [(num var1 ... varn) expr]

var -> alpha varch1 ... varchn
varch -> alpha | digit | _
```

## 解析器

手写递归下降解析器

## 转译器

从表达式到G-Machine指令

适当做一些窥孔优化

## G-Machine实现

WebAssembly/Rust + mark-copy gc 

