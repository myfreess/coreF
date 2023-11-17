fn pprDefn(defn : (String, Expr[String])) -> Doc {
  let (name, expr) = defn
  Doc::concat([text(name), text(" = "), nest(2, pprExpr(expr))])
}


fn pprDefns(defns : List[(String, Expr[String])]) -> Doc {
  let sep = text(";") + line()
  Doc::interleaveL(sep, defns.map(pprDefn))
}


pub fn pprExpr(expr : Expr[String]) -> Doc {
  match expr {
    EVar(v) => text(v)
    EAp(e1, e2) => pprExpr(e1) + text(" ") + pprExpr(e2)
    ELet(isrec, defns, expr) => {
      let keyword : String = if isrec { "letrec" } else { "let" }
      Doc::concat([ text(keyword), line(),
                    text(" "), nest(2, pprDefns(defns)), line(),
                    text("in "), pprExpr(expr)])
    }
  }
}