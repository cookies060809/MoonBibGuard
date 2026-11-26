///|
fn count_code(report : @moonbibguard.Report, code : String) -> Int32 {
  let mut n = 0
  for d in report.diagnostics {
    if d.code == code {
      n = n + 1
    }
  }
  n
}

///|
test "clean document produces no diagnostics" {
  let md = "Text [@a1]."
  let bib = "@article{a1, author = {A}, title = {T}, year = {2020}, journal = {J}}"
  let report = @moonbibguard.analyze(md, bib)
  assert_eq(report.diagnostics.length(), 0)
  assert_eq(report.error_count, 0)
  assert_eq(report.warning_count, 0)
}

///|
test "undefined citation is an error" {
  let report = @moonbibguard.analyze("[@missing]", "@misc{other, title = {O}}")
  assert_eq(count_code(report, "MBG001"), 1)
  assert_eq(report.error_count, 1)
}

///|
test "undefined citation points at line and column" {
  let report = @moonbibguard.analyze(
    "line1\nline2 [@missing]", "@misc{other, title = {O}}",
  )
  let mut line = 0
  let mut column = 0
  for d in report.diagnostics {
    if d.code == "MBG001" {
      line = d.line
      column = d.column
    }
  }
  assert_eq(line, 2)
  assert_eq(column, 9)
}

///|
test "duplicate key is reported once" {
  let report = @moonbibguard.analyze(
    "[@dup]", "@misc{dup, title = {A}}\n@misc{dup, title = {B}}",
  )
  assert_eq(count_code(report, "MBG002"), 1)
}

///|
test "unused entry is a warning" {
  let report = @moonbibguard.analyze(
    "Nothing cited here.", "@misc{lonely, title = {L}}",
  )
  assert_eq(count_code(report, "MBG003"), 1)
  assert_eq(report.warning_count, 1)
}

///|
test "missing required fields are warnings" {
  let report = @moonbibguard.analyze(
    "[@a2]", "@article{a2, title = {T}, year = {2020}}",
  )
  assert_eq(count_code(report, "MBG004"), 2)
}

///|
test "bibtex syntax error is reported" {
  let report = @moonbibguard.analyze("text", "@article{bad, title = {Unclosed")
  assert_true(count_code(report, "MBG005") >= 1)
}

///|
test "typo in citation suggests the closest key" {
  let report = @moonbibguard.analyze(
    "[@vaswani2107]", "@inproceedings{vaswani2017, author = {V}, title = {T}, year = {2017}, booktitle = {N}}",
  )
  let mut found = false
  for d in report.diagnostics {
    if d.code == "MBG001" {
      match d.suggestion {
        Some(_) => found = true
        None => ()
      }
    }
  }
  assert_true(found)
}

///|
test "summary counts citations and entries" {
  let report = @moonbibguard.analyze(
    "[@a; @b]", "@misc{a, title = {A}}\n@misc{b, title = {B}}",
  )
  assert_eq(report.citation_count, 2)
  assert_eq(report.entry_count, 2)
}

///|
test "fenced code block does not add citations" {
  let report = @moonbibguard.analyze(
    "```\n[@ghost]\n```", "@misc{ghost, title = {G}}",
  )
  assert_eq(report.citation_count, 0)
  assert_eq(count_code(report, "MBG003"), 1)
}

///|
test "levenshtein distance basic cases" {
  assert_eq(@moonbibguard.levenshtein("kitten", "sitting"), 3)
  assert_eq(@moonbibguard.levenshtein("abc", "abc"), 0)
  assert_eq(@moonbibguard.levenshtein("abc", ""), 3)
}

///|
test "required fields per entry type" {
  assert_eq(@moonbibguard.required_fields("article").length(), 4)
  assert_eq(@moonbibguard.required_fields("misc").length(), 1)
}

///|
test "several rule codes appear in one run" {
  let md = "[@missing1] [@dup]"
  let bib = "@article{dup, title = {D}}\n@article{dup, title = {D2}}\n@misc{lonely, title = {L}}"
  let report = @moonbibguard.analyze(md, bib)
  assert_true(count_code(report, "MBG001") >= 1)
  assert_true(count_code(report, "MBG002") >= 1)
  assert_true(count_code(report, "MBG003") >= 1)
}

///|
test "clean run keeps warning count at zero" {
  let report = @moonbibguard.analyze("[@ok]", "@misc{ok, title = {OK}}")
  assert_eq(report.warning_count, 0)
  assert_eq(report.error_count, 0)
}

///|
test "citation split across two documents is matched by the library" {
  let docs : Array[(String, String)] = [
    ("intro.md", "参见 [@vaswani2017]。"),
    ("method.md", "我们沿用 [@vaswani2017]。"),
  ]
  let bib = "@inproceedings{vaswani2017, author = {Vaswani}, title = {Attention}, year = {2017}, booktitle = {NeurIPS}}"
  let report = @moonbibguard.analyze_docs(docs, bib)
  assert_eq(report.error_count, 0)
  assert_eq(report.warning_count, 0)
  assert_eq(report.citation_count, 2)
}

///|
test "multi-document report points at the offending file" {
  let docs : Array[(String, String)] = [
    ("intro.md", "这里没问题 [@a]"),
    ("appendix.md", "这里引错了 [@ghost]"),
  ]
  let bib = "@misc{a, title = {A}}"
  let report = @moonbibguard.analyze_docs(docs, bib)
  let mut file_of_ghost = ""
  for d in report.diagnostics {
    if d.code == "MBG001" {
      file_of_ghost = d.file
    }
  }
  assert_eq(file_of_ghost, "appendix.md")
}

///|
test "entry cited in any document is not reported as unused" {
  let docs : Array[(String, String)] = [
    ("ch1.md", "引言"),
    ("ch2.md", "结论 [@b]"),
  ]
  let bib = "@misc{b, title = {B}}\n@misc{c, title = {C}}"
  let report = @moonbibguard.analyze_docs(docs, bib)
  assert_eq(count_code(report, "MBG003"), 1)
}

///|
test "empty document list yields an empty but valid report" {
  let docs : Array[(String, String)] = []
  let report = @moonbibguard.analyze_docs(docs, "@misc{x, title = {X}}")
  assert_eq(report.citation_count, 0)
  assert_eq(report.entry_count, 1)
  assert_eq(report.error_count, 0)
}
