## 语法设计

使用Sexpr, 参考Clojure

```
program -> sc1 ...... scn

sc -> (defn var[var1 ... varn] expr)

expr -> (expr expr1 ... exprn) // 应用
     |  ($let (defs) expr)
     |  ($letrec (defs) expr)
     |  ($case expr alts)
     |  var
     |  num
     |  Nil
     |  (Cons x xs) 

defs -> def1 ... defn
def -> [var expr]

alts -> alt1 ... altn
alt -> [pattern expr]

pattern -> (Nil) | (Cons var1 var2)

var -> alpha varch1 ... varchn
varch -> alpha | digit | _
```

## 解析器

手写递归下降解析器

## 转译器

从表达式到G-Machine指令

适当做一些优化

## G-Machine实现

mark-copy gc 

