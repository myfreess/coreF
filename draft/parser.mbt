struct Position {
  row : Int
  column : Int
}

fn Position::new(row : Int, column : Int) -> Position {
  { row, column }
}

enum Token {
  Number(Int)
  Id(String)
  Single(Char)
}

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
  self == ' ' || self == '\t'
}

fn isNewLine(self : Char) -> Bool {
  self == '\n'
}

enum Kind {
  Digit
  Alpha
  WhiteSpace
  NewLine
  Other
}

fn view(self : Char) -> Kind {
  if self.isNewLine() {
    NewLine
  } else if self.isWhiteSpace() {
    WhiteSpace
  } else if self.isAlpha() {
    Alpha
  } else if self.isDigit() {
    Digit
  } else {
    Other
  }
}

// '0'.to_number == 0
fn to_number(self : Char) -> Int {
  self.to_int() - 48
}

pub fn lex(source : String) -> List[(Token, Position)] {
  var index = 0
  var row = 0
  var column = 0
  fn forward() {
    column = column + 1
    index = index + 1
  }

  fn newline() {
    row = row + 1
    column = 0
    index = index + 1
  }

  fn go() -> List[(Token, Position)] {
    if index < source.length() {
      match source[index].view() {
        WhiteSpace => {
          forward()
          go()
        }
        NewLine => {
          newline()
          go()
        }
        Digit => {
          let pos = Position::new(row, column)
          var result = 0
          while index < source.length() && source[index].isDigit() {
            result = result * 10 + source[index].to_number()
            forward()
          }
          Cons((Number(result), pos), go())
        }
        Alpha => {
          let pos = Position::new(row, column)
          var result = ""
          while index < source.length() && source[index].isIdChar() {
            result = result + source[index].to_string()
            forward()
          }
          Cons((Id(result), pos), go())
        }
        Other => {
          let pos = Position::new(row, column)
          let result = source[index]
          forward()
          Cons((Single(result), pos), go())
        }
      }
    } else {
      return Nil
    }
  }

  go()
}

