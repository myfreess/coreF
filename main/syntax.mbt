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
} derive(Eq, Debug, Show)


fn in(this : Char, lw : Char, up : Char) -> Bool {
  this >= lw && this <= up
}

fn isDigit(this : Char) -> Bool {
  in(this, '0', '9')
}

fn isAlpha(this : Char) -> Bool {
  in(this, 'A', 'Z') || in(this, 'a', 'z')
}

fn isIdChar(this : Char) -> Bool {
  isAlpha(this) || isDigit(this) || this == '_' || this == '-'
}

fn isWhiteSpace(this : Char) -> Bool {
  this == ' ' || this == '\t' || this == '\n'
}

fn to_number(this : Char) -> Int {
  this.to_int() - 48
}

fn isOpen(this : Char) -> Bool {
  this == '(' || this == '[' || this == '{'
}

fn isClose(this : Char) -> Bool {
  this == ')' || this == ']' || this == '}'
}

struct TokenStream {
  mut tokens : List[Token]
} // derive (Show)

fn TokenStream::new(source : String) -> TokenStream {
  let mut base = 0
  fn tokenize() -> List[Token] {
    if base < source.length() {
      let ch = source[base]
      if isWhiteSpace(ch) {
        base = base + 1
        tokenize()
      } else if isDigit(ch) {
        let mut num = to_number(ch)
        base = base + 1
        while base < source.length() && isDigit(source[base]) {
          num = num * 10 + to_number(source[base])
          base = base + 1 
        }
        Cons(Token::Number(num), tokenize())
      } else if isOpen(ch) {
        base = base + 1
        Cons(Token::Open(ch), tokenize())
      } else if isClose(ch) {
        base = base + 1
        Cons(Token::Close(ch), tokenize())
      } else if isAlpha(ch) {
        let mut id = ch.to_string()
        base = base + 1
        while base < source.length() && isIdChar(source[base]) {
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
    Cons(_, ts) => {
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
    otherwise => abort("parsePack(): wrong token \(otherwise) ")
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
  let mut res : List[(String, RawExpr[String])] = Nil
  while self.peek() == Open('[') {
    self.next()
    let variable = parseVar(self)
    let value = parseExpr(self)
    self.eat(Close(']'))
    res = Cons((variable, value), res)
  }
  res = reverse(res)
  return res
}

fn parseAlts(self : TokenStream) -> List[(Int, List[String], RawExpr[String])] {
  let mut res : List[(Int, List[String], RawExpr[String])] = Nil
  while self.peek() == Open('[') {
    self.next()
    self.eat(Open('('))
    let tag = parseNum(self)
    let mut variables : List[String] = Nil
    while self.peek() != Close(')') {
      let variable = parseVar(self)
      variables = Cons(variable, variables)
    }
    variables = reverse(variables)
    self.eat(Close(')'))
    let exp = parseExpr(self)
    let alt = (tag, variables, exp)
    res = Cons(alt, res)
  }
  res = reverse(res)
  return res
}

fn parseAp(self : TokenStream) -> RawExpr[String] {
  let mut res = parseExpr(self)
  while self.peek() != Close(')') {
    res = App(res, parseExpr(self))
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
      let mut exp : RawExpr[String] = Var("dummy")
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
  let mut arglist : List[String] = Nil
  while self.peek() != Close(']') {
    let varname = parseVar(self)
    arglist = Cons(varname, arglist)
  }
  arglist = reverse(arglist)
  self.next()
  let body = parseExpr(self)
  { name : fnname, args : arglist, body : body }
}