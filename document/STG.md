STG的全称Spineless Tagless G-Machine中包含了两种针对G-Machine的改进

## Spineless

对应论文*The Spineless G-Machine*。

## Tagless

对应论文*Implementing lazy functional languages on stock hardware: the Spineless Tagless G-machine*。



## GHC在实用性上做出的改进

2004年，Simon Marlow和SPJ发现早期被放弃的函数应用模型`Eval-Apply`在编译的情况下比`Push-Enter`模型更高效。

2007年，Simon Marlow发现tagless设计中的跳转并执行代码对现代CPU的分支预测器性能影响很大。解决方案在论文`Faster laziness using dynamic pointer tagging`中描述了几种。