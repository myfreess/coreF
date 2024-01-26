fn test_genB {
  let group = @lib.Doc::Group
  let append = fn (x, y){ @lib.Doc::Append(x, y) }
  let text = @lib.Doc::Text
  let line = @lib.Doc::Line
  let doc1 = group(append(text("A"), append(line, group(append(text("B"), append(line, text("C")))))))
  doc1.genB().runWith(fn (node) { println("Generated: \(node)")})
}

fn test_trHPB() {
  let group = @lib.Doc::Group
  let append = fn (x, y){ @lib.Doc::Append(x, y) }
  let text = @lib.Doc::Text
  let line = @lib.Doc::Line
  let doc1 = group(append(text("A"), append(line, group(append(text("B"), append(line, text("C")))))))
  let prod = @lib.trHPB(doc1.genB())
  @lib.runWith(prod, fn (node ) { println("Generated: \(node)")})
}
