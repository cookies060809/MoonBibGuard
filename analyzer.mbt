///|
fn min3(a : Int32, b : Int32, c : Int32) -> Int32 {
  let m = if a < b { a } else { b }
  if m < c {
    m
  } else {
    c
  }
}

///|
/// Standard Levenshtein edit distance, used for "did you mean" suggestions.
pub fn levenshtein(a : String, b : String) -> Int32 {
  let ca = a.to_array()
  let cb = b.to_array()
  let n = ca.length()
  let m = cb.length()
  if n == 0 {
    return m
  }
  if m == 0 {
    return n
  }
  let prev : Array[Int32] = Array::make(m + 1, 0)
  let cur : Array[Int32] = Array::make(m + 1, 0)
  for j = 0; j <= m; j = j + 1 {
    prev[j] = j
  }
  for i = 1; i <= n; i = i + 1 {
    cur[0] = i
    for j = 1; j <= m; j = j + 1 {
      let cost = if ca[i - 1] == cb[j - 1] { 0 } else { 1 }
      let del_cost = prev[j] + 1
      let ins_cost = cur[j - 1] + 1
      let sub_cost = prev[j - 1] + cost
      cur[j] = min3(del_cost, ins_cost, sub_cost)
    }
    for j = 0; j <= m; j = j + 1 {
      prev[j] = cur[j]
    }
  }
  prev[m]
}

///|
/// Fields that each BibTeX entry type must carry.
pub fn required_fields(entry_type : String) -> Array[String] {
  match entry_type {
    "article" => ["author", "title", "year", "journal"]
    "inproceedings" | "conference" => ["author", "title", "year", "booktitle"]
    "book" | "booklet" => ["title", "publisher", "year"]
    "incollection" => ["author", "title", "booktitle", "year"]
    "phdthesis" | "mastersthesis" => ["author", "title", "school", "year"]
    "techreport" => ["author", "title", "institution", "year"]
    "misc" | "online" | "unpublished" => ["title"]
    _ => ["title"]
  }
}

///|
/// Analyzes one Markdown document against one BibTeX library and returns
/// a report with error codes, positions and fix suggestions.
pub fn analyze(
  markdown_text : String,
  bibtex_text : String,
  markdown_file~ : String = "paper.md",
  bib_file~ : String = "references.bib",
) -> Report {
  let db = parse_bibtex(bibtex_text)
  let cites = extract_citations(markdown_text)
  let diags : Array[Diagnostic] = []
  let index : Map[String, Array[BibEntry]] = Map([])
  for entry in db.entries {
    match index.get(entry.key) {
      Some(list) => list.push(entry)
      None => index.set(entry.key, [entry])
    }
  }
  // MBG005: BibTeX syntax problems
  for err in db.errors {
    diags.push({
      code: "MBG005",
      severity: Error,
      file: bib_file,
      line: err.line,
      column: 0,
      message: "BibTeX 语法错误：\{err.message}",
      suggestion: None,
    })
  }
  // MBG002: duplicated keys
  let seen : Map[String, Int32] = Map([])
  for entry in db.entries {
    match seen.get(entry.key) {
      Some(first_line) =>
        diags.push({
          code: "MBG002",
          severity: Error,
          file: bib_file,
          line: entry.line,
          column: 0,
          message: "重复的引用键 \{entry.key}，它已在第 \{first_line} 行定义过",
          suggestion: Some("为其中一条文献改用唯一的引用键"),
        })
      None => seen.set(entry.key, entry.line)
    }
  }
  // MBG004: missing required fields
  for entry in db.entries {
    for field in required_fields(entry.entry_type) {
      match entry.fields.get(field) {
        Some(_) => ()
        None =>
          diags.push({
            code: "MBG004",
            severity: Warning,
            file: bib_file,
            line: entry.line,
            column: 0,
            message: "条目 \{entry.key}（@\{entry.entry_type}）缺少字段 \{field}",
            suggestion: Some(
              "补全 \{field} 字段，否则导出参考文献时该条目可能显示不完整",
            ),
          })
      }
    }
  }
  // MBG001: undefined citations
  for cite in cites {
    match index.get(cite.key) {
      Some(_) => ()
      None => {
        let mut best = ""
        let mut best_distance = 3
        for entry in db.entries {
          let d = levenshtein(cite.key, entry.key)
          if d < best_distance {
            best_distance = d
            best = entry.key
          }
        }
        let suggestion = if best_length_ok(best, cite.key) {
          Some("是否想引用 \{best}？编辑距离 \{best_distance}")
        } else {
          None
        }
        diags.push({
          code: "MBG001",
          severity: Error,
          file: markdown_file,
          line: cite.line,
          column: cite.column,
          message: "未定义引用 \{cite.key}：文献库中不存在该引用键",
          suggestion,
        })
      }
    }
  }
  // MBG003: unused entries
  let cited : Map[String, Bool] = Map([])
  for cite in cites {
    cited.set(cite.key, true)
  }
  for entry in db.entries {
    match cited.get(entry.key) {
      Some(_) => ()
      None =>
        diags.push({
          code: "MBG003",
          severity: Warning,
          file: bib_file,
          line: entry.line,
          column: 0,
          message: "未使用文献 \{entry.key}：正文中没有引用它",
          suggestion: Some("删除该条目，或在正文中补上引用"),
        })
    }
  }
  let mut error_count = 0
  let mut warning_count = 0
  let mut info_count = 0
  for d in diags {
    match d.severity {
      Error => error_count = error_count + 1
      Warning => warning_count = warning_count + 1
      Info => info_count = info_count + 1
    }
  }
  {
    diagnostics: diags,
    error_count,
    warning_count,
    info_count,
    citation_count: cites.length(),
    entry_count: db.entries.length(),
  }
}

///|
fn best_length_ok(best : String, key : String) -> Bool {
  match levenshtein(best, key) {
    1 | 2 => best.length() >= 4
    _ => false
  }
}
