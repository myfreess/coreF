enum Doc {
  Nil
  Text(String, Doc)
  Line(Int, Doc)
}

pub fn op_add(self : Doc, x : Doc) -> Doc {
  match self {
    Text(s, d) => Text(s, op_add(d, x))
    Line(indent, d) => Line(indent, op_add(d, x))
    Nil => x
  }
}

pub fn nil() -> Doc {
  Nil
}

pub fn text(s : String) -> Doc {
  Text(s, Nil)
}

pub fn line() -> Doc {
  Line(0, Nil)
}

pub fn nest(base : Int, document : Doc) -> Doc {
  match document {
    Text(s, d) => Text(s, nest(base, d))
    Line(i, d) => Line(base + i, nest(base, d))
    Nil => Nil
  }
}

fn blank(n : Int) -> String {
  String::make(n, ' ')
}

pub fn Doc::concat(docs : Array[Doc]) -> Doc {
  var result : Doc = nil()
  var i = docs.length() - 1
  while i >= 0 {
    result = docs[i] + result
    i = i - 1
  }
  return result
}

pub fn Doc::interleave(sep : Doc, docs : Array[Doc]) -> Doc {
  var result : Doc = nil()
  var i = docs.length() - 1
  while i >= 0 {
    if i == docs.length() - 1 {
      result = docs[i] + result
    } else {
      result = docs[i] + (sep + result)
    }
    i = i - 1
  }
  return result
}

pub fn Doc::interleaveL(sep : Doc, docs : List[Doc]) -> Doc {
  match docs {
    Nil => nil()
    Cons(x, Nil) => x
    Cons(x, xs) => x + (sep + Doc::interleaveL(sep, xs))
  }
}

pub fn spprint(document : Doc) {
  match document {
    Text(s, document) => {
      print(s)
      spprint(document)
    }
    Line(indent, document) => {
      print("\n")
      print(blank(indent))
      spprint(document)
    }
    Nil => ()
  }
}


