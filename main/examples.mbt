let coref_square =
  #| (defn square[x] (mul x x))

let coref_fix =
  #| (defn fix[f] (letrec ([x (f x)]) x))