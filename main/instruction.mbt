enum Instruction {
  Unwind
  PushGlobal(String)
  PushInt(Int)
  PushArg(Int)
  MkApp
  Slide(Int)
  Update(Int)
} derive (Eq, Debug, Show)