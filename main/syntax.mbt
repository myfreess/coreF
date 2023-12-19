enum Token {
  DefFn
  Let
  Pack
  Case
  Letrec
  Open(Char)  // { [ (
  Close(Char) // } ] )
  Id(String)
  Number(Int)
  EOF
} derive(Eq, Show)


fn in(self : Char, lw : Char, up : Char) -> Bool {
  self >= lw && self <= up
}

fn isDigit(self : Char) -> Bool {
  self.in('0', '9')
}

fn isAlpha(self : Char) -> Bool {
  self.in('A', 'Z') || self.in('a', 'z')
}

fn isIdChar(self : Char) -> Bool {
  self.isAlpha() || self.isDigit() || self == '_' || self == '-'
}

fn isWhiteSpace(self : Char) -> Bool {
  self == ' ' || self == '\t' || self == '\n'
}

fn to_number(self : Char) -> Int {
  self.to_int() - 48
}

fn isOpen(self : Char) -> Bool {
  self == '(' || self == '[' || self == '{'
}

fn isClose(self : Char) -> Bool {
  self == ')' || self == ']' || self == '}'
}

struct TokenStream {
  mut tokens : List[Token]
} derive (Show)

fn TokenStream::new(source : String) -> TokenStream {
  var base = 0
  fn tokenize() -> List[Token] {
    if base < source.length() {
      let ch = source[base]
      if ch.isWhiteSpace() {
        base = base + 1
        tokenize()
      } else if ch.isDigit() {
        var num = ch.to_number()
        base = base + 1
        while base < source.length() && source[base].isDigit() {
          num = num * 10 + source[base].to_number()
          base = base + 1 
        }
        Cons(Token::Number(num), tokenize())
      } else if ch.isOpen() {
        base = base + 1
        Cons(Token::Open(ch), tokenize())
      } else if ch.isClose() {
        base = base + 1
        Cons(Token::Close(ch), tokenize())
      } else if ch.isAlpha() {
        var id = ch.to_string()
        base = base + 1
        while base < source.length() && source[base].isIdChar() {
          id = id + source[base].to_string()
          base = base + 1
        }
        if id == "let" {
          Cons(Token::Let, tokenize())
        } else if id == "letrec" {
          Cons(Token::Letrec, tokenize())
        } else if id == "pack" {
          Cons(Token::Pack, tokenize())
        } else if id == "case" {
          Cons(Token::Case, tokenize())
        } else if id == "defn" {
          Cons(Token::DefFn, tokenize())
        } else { 
          Cons(Token::Id(id), tokenize())
        }
      } else {
        let ch = source[base]
        abort("error : invalid Character '\(ch)' in [\(base)]")
      }
    } else {
      return Nil
    }
  }
  { tokens : tokenize() }
}

fn peek(self : TokenStream) -> Token {
  match self.tokens {
    Cons(t, _) => t
    Nil => Token::EOF
  }
}

fn next(self : TokenStream) {
    match self.tokens {
    Cons(t, ts) => {
      self.tokens = ts
    }
    Nil => abort("next() : empty stream")
  }
}

fn eat(self : TokenStream, tok : Token) {
  let res = self.peek()
  if (tok != res) {
    abort("eat(): require token \(tok), but got \(res)")
  } else {
    self.next()
  }
} 



fn parseNum(self : TokenStream) -> Int {
  match self.peek() {
    Number(n) => {
      self.next()
      n
    }
    other => {
      abort("parse(): expect a number but got \(other)")
    }
  }
}

fn parseVar(self : TokenStream) -> String {
  match self.peek() {
    Id(s) => {
      self.next()
      s
    }
    other => {
      abort("parse(): expect a variable but got \(other)")
    }
  }
}

fn parsePack(self : TokenStream) -> RawExpr[String] {
  match self.peek() {
    Pack => {
      self.next()
      let tag = parseNum(self)
      let arity = parseNum(self)
      Constructor(tag, arity)
    }
  }
}

fn parseLet(self : TokenStream) -> RawExpr[String] {
  self.eat(Let)
  self.eat(Open('('))
  let defs = parseDefs(self)
  self.eat(Close(')'))
  let exp = parseExpr(self)
  Let(false, defs, exp)
}

fn parseLetrec(self : TokenStream) -> RawExpr[String] {
  self.eat(Letrec)
  self.eat(Open('('))
  let defs = parseDefs(self)
  self.eat(Close(')'))
  let exp = parseExpr(self)
  Let(true, defs, exp)
}

fn parseCase(self : TokenStream) -> RawExpr[String] {
  self.eat(Case)
  let exp = parseExpr(self)
  let alts = parseAlts(self)
  Case(exp, alts)
}

fn parseDefs(self : TokenStream) -> List[(String, RawExpr[String])] {
  var res : List[(String, RawExpr[String])] = Nil
  while self.peek() == Open('[') {
    self.next()
    let variable = parseVar(self)
    let value = parseExpr(self)
    self.eat(Close(']'))
    res = Cons((variable, value), res)
  }
  res = res.reverse()
  return res
}

fn parseAlts(self : TokenStream) -> List[(Int, List[String], RawExpr[String])] {
  var res : List[(Int, List[String], RawExpr[String])] = Nil
  while self.peek() == Open('[') {
    self.next()
    self.eat(Open('('))
    let tag = parseNum(self)
    var variables : List[String] = Nil
    while self.peek() != Close(')') {
      let variable = parseVar(self)
      variables = Cons(variable, variables)
    }
    variables = variables.reverse()
    self.eat(Close(')'))
    let exp = parseExpr(self)
    let alt = (tag, variables, exp)
    res = Cons(alt, res)
  }
  res = res.reverse()
  return res
}

fn parseAp(self : TokenStream) -> RawExpr[String] {
  var res = parseExpr(self)
  while self.peek() != Close(')') {
    res = Ap(res, parseExpr(self))
  }
  return res
}

fn parseExpr(self : TokenStream) -> RawExpr[String] {
  match self.peek() {
    EOF => {
      abort("parse() : expect a token but got a empty token stream")
    }
    Number(n) => {
      self.next()
      Num(n)
    }
    Id(s) => {
      self.next()
      Var(s)
    }
    Open('(') => {
      self.next()
      var exp : RawExpr[String] = Var("dummy")
      match self.peek() {
        Let => {
          exp = parseLet(self)
        }
        Letrec => {
          exp = parseLetrec(self)
        }
        Case => {
          exp = parseCase(self)
        }
        Pack => {
          exp = parsePack(self)
        }
        Id(_) => {
          exp = parseAp(self)
        }
        Open('(') => {
          exp = parseAp(self)
        }
        other => {
          abort("parse(): cant parse \(other) behind a '('")
        }
      }
      self.eat(Close(')'))
      return exp
    }
    other => {
      abort("parse(): cant parse \(other)")
    }
  }
}

fn parseSC(self : TokenStream) -> ScDef[String] {
  self.eat(Open('('))
  self.eat(DefFn)
  let fnname = parseVar(self)
  self.eat(Open('['))
  var arglist : List[String] = Nil
  while self.peek() != Close(']') {
    let varname = parseVar(self)
    arglist = Cons(varname, arglist)
  }
  arglist = arglist.reverse()
  self.next()
  let body = parseExpr(self)
  { name : fnname, args : arglist, body : body }
}