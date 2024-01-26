pub enum Doc {
  Text(String)
  Line
  Append(Doc, Doc)
  Group(Doc)
}

pub fn concatDoc(arr : Array[Doc]) -> Doc {
  var result = arr[arr.length() - 1]
  var i = arr.length() - 2
  while i >= 0 {
    result = Append(arr[i], result)
    i = i - 1
  }
  return result
}

pub enum StreamB {
  TE(String)
  LE
  GBeg
  GEnd
}

pub fn to_string(self : StreamB) -> String {
  match self {
    TE(s) => "TE(\(s))"
    LE => "LE"
    GBeg => "GBeg"
    GEnd => "GEnd"
  }
}

pub fn genB(self : Doc) -> Producer[StreamB] {
  match self {
    Text(s) => yield(TE(s)) // assert s != ""
    Line => yield(LE)
    Append(d1, d2) => { 
      genB(d1).then(fn () {
        genB(d2)
      })
    }
    Group(d) => {
      let begin : StreamB = GBeg
      let end : StreamB = GEnd
      yield(begin).then(fn () {
        genB(d)
      }).then(fn () {
        yield(end)
      })
    }
  }
} 

pub enum StreamHPB {
  TEHPB(Int, String)
  LEHPB(Int)
  GBegHPB(Int)
  GEndHPB(Int)
}

pub fn to_string(self : StreamHPB) -> String {
  match self {
    TEHPB(w, s) => "TE(\(w), \(s))"
    LEHPB(w) => "LE(\(w))"
    GBegHPB(w) => "GBeg(\(w))"
    GEndHPB(w) => "GEnd(\(w))"
  }
}

// each node is annotated with the sum of the widths of all preceding nodes including the current
pub fn trHPB(inputs : Producer[StreamB]) -> Producer[StreamHPB] {
  let width = fn (node : StreamB) {
    match node {
      TE(s) => s.length()
      LE => 1
      GBeg => 0
      GEnd => 0
    }
  }
  let (prod, _) = inputs.foldG(
    (Producer::empty(), 0),
    fn (state, current) {
      let (prod, widthSum) = state
      let widthSum = widthSum + width(current)
      let newNode : StreamHPB = match current {
        TE(s) => TEHPB(widthSum, s)
        LE => LEHPB(widthSum)
        GBeg => GBegHPB(widthSum)
        GEnd => GEndHPB(widthSum)
      }
      (prod.then(fn () { yield(newNode) }), widthSum)
    })
    return prod
}

struct RefHP {
  mut modifiable : Bool
  mut hp : Int
}

// RefHP对外提供的方法: new read set to_string

fn RefHP::new(x : Int) -> RefHP {
  { modifiable : true, hp : x }
}

pub fn set(self : RefHP, val : Int) {
  if self.modifiable {
    self.hp = val
    self.modifiable = false
  } else {
    abort("RefHP::set() : cannot set")
  }
}

pub fn read(self : RefHP) -> Int {
  return self.hp
}

pub fn to_string(self : RefHP) -> String {
  self.hp.to_string()
}

pub enum StreamHPA {
  TEHPA(Int, String)
  LEHPA(Int)
  GBegHPA(RefHP)
  GendHPA(Int)
}

