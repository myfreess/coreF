fn parse(code : String) -> ScDef[String] {
  let code = TokenStream::new(code)
  let code = parseSC(code)
  return code
}



fn parse_then_compile(code : String) -> (String, Int, List[Instruction]) {
  let code = TokenStream::new(code)
  let code = parseSC(code)
  let code = compileSC(code)
  return code
}

let banner =                                           
#|                                          ,---,. 
#|                                        ,'  .' | 
#|              ,---.    __  ,-.        ,---.'   | 
#|             '   ,'\ ,' ,'/ /|        |   |   .' 
#|     ,---.  /   /   |'  | |' | ,---.  :   :  :   
#|    /     \.   ; ,. :|  |   ,'/     \ :   |  |-, 
#|   /    / ''   | |: :'  :  / /    /  ||   :  ;/| 
#|  .    ' / '   | .; :|  | ' .    ' / ||   |   .' 
#|  '   ; :__|   :    |;  : | '   ;   /|'   :  '   
#|  '   | '.'|\   \  / |  , ; '   |  / ||   |  |   
#|  |   :    : `----'   ---'  |   :    ||   :  \   
#|   \   \  /                  \   \  / |   | ,'   
#|    `----'                    `----'  `----'     
#|                                                 


fn run(codes : List[String]) -> Unit {
  println(banner)
  println("当前程序：\n\n")
  loop codes {
    Nil => ()
    Cons(s, ss) => {
      println(s)
      println("")
      continue ss
    }
  }
  println("\n\n")
  let codes = append(map(parse_then_compile, codes), map(compileSC, preludeDefs))
  let codes = append(compiledPrimitives, codes)
  let (heap, globals) = buildInitialHeap(codes)
  let initialState : GState = {
    output : Buffer::make(100),
    dump : initialDump,
    heap : heap,
    stack : Nil,
    code : initialCode,
    globals : globals,
    stats : initialStat
  }
  initialState.reify()
}


fn fulltest() -> Unit {
  let take = prog["take"].unwrap()
  let tail = prog["tail"].unwrap()
  let zipWith = prog["zipWith"].unwrap()
  let fibs = prog["fibs"].unwrap()
  let fac = prog["factorial"].unwrap()
  let abs = prog["abs"].unwrap()
  let len = prog["length"].unwrap()
  let main = "(defn main[] (length (Cons 4 Nil)))"
  run(List::[len, main])
}

fn main {
  fulltest()
}
