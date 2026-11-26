///|
test "empty library yields no entries and no errors" {
  let db = @moonbibguard.parse_bibtex("")
  assert_eq(db.entries.length(), 0)
  assert_eq(db.errors.length(), 0)
}

///|
test "single entry exposes key and type" {
  let db = @moonbibguard.parse_bibtex(
    "@article{a1, title = {T}, year = {2020}}",
  )
  assert_eq(db.entries.length(), 1)
  assert_eq(db.entries[0].key, "a1")
  assert_eq(db.entries[0].entry_type, "article")
}

///|
test "title field is parsed" {
  let db = @moonbibguard.parse_bibtex("@misc{k, title = {Hello World}}")
  assert_eq(db.entries[0].title, "Hello World")
}

///|
test "author and year fields are parsed" {
  let db = @moonbibguard.parse_bibtex(
    "@book{b1, author = {Knuth, Donald}, year = {1984}}",
  )
  assert_eq(db.entries[0].author, "Knuth, Donald")
  assert_eq(db.entries[0].year, "1984")
}

///|
test "multi-line field value is joined" {
  let db = @moonbibguard.parse_bibtex(
    "@article{m1, title = {A long\n    title}, year = {2021}}",
  )
  assert_eq(db.entries[0].title, "A long title")
}

///|
test "nested braces are preserved in value" {
  let db = @moonbibguard.parse_bibtex(
    "@article{n1, title = {A {Nested} Title}}",
  )
  assert_eq(db.entries[0].title, "A {Nested} Title")
}

///|
test "quoted value is parsed" {
  let db = @moonbibguard.parse_bibtex("@article{q1, title = \"Quoted Value\"}")
  assert_eq(db.entries[0].title, "Quoted Value")
}

///|
test "bare value is parsed" {
  let db = @moonbibguard.parse_bibtex("@article{bar1, year = 2017}")
  assert_eq(db.entries[0].year, "2017")
}

///|
test "multiple entries are parsed in order" {
  let db = @moonbibguard.parse_bibtex(
    "@misc{a, title = {A}}\n@misc{b, title = {B}}",
  )
  assert_eq(db.entries.length(), 2)
  assert_eq(db.entries[1].key, "b")
}

///|
test "comment and string entries are skipped" {
  let db = @moonbibguard.parse_bibtex(
    "@comment{not an entry}\n@string{conf = {NeurIPS}}\n@misc{real, title = {Real}}",
  )
  assert_eq(db.entries.length(), 1)
  assert_eq(db.entries[0].key, "real")
}

///|
test "parenthesised entry is parsed" {
  let db = @moonbibguard.parse_bibtex(
    "@article(p1, title = {Paren}, year = {2020})",
  )
  assert_eq(db.entries.length(), 1)
  assert_eq(db.entries[0].title, "Paren")
}

///|
test "duplicate keys are both kept for later analysis" {
  let db = @moonbibguard.parse_bibtex(
    "@misc{dup, title = {A}}\n@misc{dup, title = {B}}",
  )
  assert_eq(db.entries.length(), 2)
}

///|
test "unclosed entry reports an error" {
  let db = @moonbibguard.parse_bibtex("@article{bad, title = {Unclosed")
  assert_true(db.errors.length() >= 1)
}

///|
test "missing equals reports an error" {
  let db = @moonbibguard.parse_bibtex("@article{bad2, title {NoEq}}")
  assert_true(db.errors.length() >= 1)
}

///|
test "missing opening brace reports an error" {
  let db = @moonbibguard.parse_bibtex("@article a1, title = {T}}")
  assert_true(db.errors.length() >= 1)
}

///|
test "percent comment lines are ignored" {
  let db = @moonbibguard.parse_bibtex(
    "% a comment line\n@misc{c1, title = {C}}",
  )
  assert_eq(db.entries.length(), 1)
}

///|
test "entry line numbers follow the source" {
  let db = @moonbibguard.parse_bibtex(
    "@misc{first, title = {A}}\n\n@misc{second, title = {B}}",
  )
  assert_eq(db.entries[0].line, 1)
  assert_eq(db.entries[1].line, 3)
}

///|
test "chinese title survives parsing" {
  let db = @moonbibguard.parse_bibtex("@misc{cn, title = {中文标题测试}}")
  assert_eq(db.entries[0].title, "中文标题测试")
}

///|
test "whitespace runs collapse inside values" {
  let db = @moonbibguard.parse_bibtex(
    "@article{w1, title = {Deep    Learning    Works}}",
  )
  assert_eq(db.entries[0].title, "Deep Learning Works")
}

///|
test "@string macro is expanded in field values" {
  let db = @moonbibguard.parse_bibtex(
    "@string{acm = {ACM Press}}\n@book{b1, publisher = acm, title = {T}}",
  )
  assert_eq(db.errors.length(), 0)
  assert_eq(db.entries[0].fields.get("publisher").unwrap(), "ACM Press")
}

///|
test "hash concatenation joins literal and macro parts" {
  let db = @moonbibguard.parse_bibtex(
    "@string{conf = {Proc. of ICML}}\n@inproceedings{p1, booktitle = conf # { 2023}, title = {T}}",
  )
  assert_eq(db.errors.length(), 0)
  assert_eq(
    db.entries[0].fields.get("booktitle").unwrap(),
    "Proc. of ICML 2023",
  )
}

///|
test "quoted value supports hash concatenation" {
  let db = @moonbibguard.parse_bibtex(
    "@string{org = {OpenAI}}\n@misc{m1, author = org # { Team}, title = {T}}",
  )
  assert_eq(db.entries[0].fields.get("author").unwrap(), "OpenAI Team")
}

///|
test "string macro names are case insensitive" {
  let db = @moonbibguard.parse_bibtex(
    "@string{IEEE = {IEEE Press}}\n@book{b1, publisher = ieee, title = {T}}",
  )
  assert_eq(db.entries[0].fields.get("publisher").unwrap(), "IEEE Press")
}

///|
test "unknown bare word is kept verbatim instead of dropped" {
  let db = @moonbibguard.parse_bibtex("@misc{m1, title = {T}, month = jan}")
  assert_eq(db.entries[0].fields.get("month").unwrap(), "jan")
}

///|
test "@string definitions are exposed through the macros map" {
  let db = @moonbibguard.parse_bibtex("@string{my = {Val}}")
  assert_eq(db.macros.get("my").unwrap(), "Val")
  assert_eq(db.macros.length(), 1)
}

///|
test "missing closing brace in @string reports an error" {
  let db = @moonbibguard.parse_bibtex("@string{broken = {Val}")
  assert_eq(db.errors.length(), 1)
}

///|
test "entry with few fields still parses after @string block" {
  let db = @moonbibguard.parse_bibtex(
    "@string{acm = {ACM}}\n@book{b1, title = {T}}",
  )
  assert_eq(db.entries.length(), 1)
  assert_eq(db.errors.length(), 0)
}
