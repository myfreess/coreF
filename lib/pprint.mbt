enum Doc {
  Text(String)
  Line
  Append(Int, Doc, Doc)
  Group(Int, Doc)
}

fn width(self : Doc) -> Int {
  match self {
    Text(s) => s.length()
    Line => 1
    Append(w, _, _) => w
    Group(w, _) => w
  }
}

pub fn text(s : String) -> Doc {
  return Text(s)
}

pub fn line() -> Doc {
  return Line
}

pub fn op_add(self : Doc, x : Doc) -> Doc {
  let width = self.width() + x.width()
  return Append(width, self, x)
}

pub fn group(self : Doc) -> Doc {
  let width = self.width()
  return Group(width, self)
}

pub fn spprint(width : Int, document : Doc) -> String {
  fn format(fit : Bool, widthLeft : Int, document : Doc) -> (String, Int) {
    match document {
      Text(s) => (s, widthLeft - s.length())
      Line =>
        if fit {
          (" ", widthLeft - 1)
        } else {
          ("\n", width)
        }
      Append(_, d1, d2) => {
        let (s1, r1) = format(fit, widthLeft, d1)
        let (s2, r2) = format(fit, r1, d2)
        (s1 + s2, r2)
      }
      Group(w, d) => format((fit || w <= widthLeft), widthLeft, d)
    }
  }
  let (str, _) = format(false, width, document)
  return str
}