STG的全称Spineless Tagless G-Machine中包含了两种针对G-Machine的改进

## Spineless

对应论文*The Spineless G-Machine*。

## Tagless

对应论文*Implementing lazy functional languages on stock hardware: the Spineless Tagless G-machine*。

STG有五种堆对象：

> 此处参考的STG对象定义来自论文Making a Fast Curry: Push/Enter vs. Eval/Apply for Higher-order Languages

+ FUN(x1 ... xN -> e) - 函数
+ PAP(f - a1 ... aN) - 偏应用
+ CON(C - a1 ... aN) - 值构造子，参数一定不会少
+ THUNK(e) - 待计算的表达式
+ BLACKHOLE - 在thunk求值期间用来代替该thunk的对象

## GHC在实用性上做出的改进

2004年，Simon Marlow和SPJ发现早期被放弃的函数应用模型`Eval-Apply`在编译的情况下比`Push-Enter`模型更高效。

2007年，Simon Marlow发现tagless设计中的跳转并执行代码对现代CPU的分支预测器性能影响很大。解决方案在论文`Faster laziness using dynamic pointer tagging`中描述了几种。