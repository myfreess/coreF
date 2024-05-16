
let prog : RHTable[String, String] = {
  let table = RHTable::new(40)
  table["square"] =
    #| (defn square[x] (mul x x))
  table["fix"] =
    #| (defn fix[f] (letrec ([x (f x)]) x))
  table["isNil"] =
    #| (defn isNil[x]
    #|   (case x [(Nil) 1] [(Cons n m) 0]))
  table["tail"] = 
    #| (defn tail[l] (case l [(Cons x xs) xs]))
  table["fibs"] =
    // fibs = 0 : 1 : zipWith (+) fibs (tail fibs)
    #| (defn fibs[] (Cons 0 (Cons 1 (zipWith add fibs (tail fibs)))))
  table["take"] =
    #| (defn take[n l]
    #|   (case l
    #|     [(Nil) Nil]
    #|     [(Cons x xs)
    #|        (if (le n 0) Nil (Cons x (take (sub n 1) xs)))]))
  table["zipWith"] =
    #| (defn zipWith[op l1 l2]
    #|   (case l1
    #|     [(Nil) Nil]
    #|     [(Cons x xs)
    #|       (case l2
    #|         [(Nil) Nil]
    #|         [(Cons y ys) (Cons (op x y) (zipWith op xs ys))])]))
  table
}