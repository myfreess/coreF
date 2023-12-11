enum Token {
  Open(Char)  // { [ (
  Close(Char) // } ] )
  Identifier(String)
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
  self.isAlpha() || self.isDigit() || self == '_'
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
}

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
          num = base * 10 + source[base].to_number()
          base = base + 1 
        }
        Cons(Number(num), tokenize())
      } else if ch.isOpen() {
        base = base + 1
        Cons(Open(ch), tokenize())
      } else if ch.isClose() {
        base = base + 1
        Cons(Close(ch), tokenize())
      } else if ch.isAlpha() {
        var id = ch.to_string()
        base = base + 1
        while base < source.length() && source[base].isIdChar() {
          id = id + source[base].to_string()
          base = base + 1
        }
        Cons(Identifier(id), tokenize())
      } else {
        abort("invalid Char")
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

fn next(self : TokenStream) -> Token {
    match self.tokens {
    Cons(t, ts) => {
      self.tokens = ts
      t
    }
    Nil => Token::EOF
  }
}

