///|
/// A single BibTeX entry with the fields MoonBibGuard cares about.
pub(all) struct BibEntry {
  key : String
  entry_type : String
  title : String
  year : String
  author : String
  fields : Map[String, String]
  line : Int32
}

///|
/// A syntax problem found while parsing a `.bib` file.
pub(all) struct BibParseError {
  line : Int32
  message : String
}

///|
/// Result of parsing one `.bib` file.
pub(all) struct BibDatabase {
  entries : Array[BibEntry]
  errors : Array[BibParseError]
  macros : Map[String, String]
}

///|
fn char_is_alpha(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

///|
fn char_is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn char_is_space(c : Char) -> Bool {
  c == ' ' || c == '\t' || c == '\r' || c == '\n'
}

///|
fn char_is_key_body(c : Char) -> Bool {
  char_is_alpha(c) ||
  char_is_digit(c) ||
  c == '_' ||
  c == '-' ||
  c == ':' ||
  c == '.' ||
  c == '/' ||
  c == '+'
}

///|
fn slice_to_string(cs : Array[Char], start : Int32, stop : Int32) -> String {
  let sb = StringBuilder()
  let n = cs.length()
  let mut i = start
  while i < stop && i < n {
    sb.write_char(cs[i])
    i = i + 1
  }
  sb.to_string()
}

///|
fn lowercase(s : String) -> String {
  s.to_lower()
}

///|
fn trim_ascii(s : String) -> String {
  let cs = s.to_array()
  let mut a = 0
  let mut b = cs.length()
  while a < b && char_is_space(cs[a]) {
    a = a + 1
  }
  while b > a && char_is_space(cs[b - 1]) {
    b = b - 1
  }
  slice_to_string(cs, a, b)
}

///|
fn skip_space(
  cs : Array[Char],
  n : Int32,
  pos : Int32,
  line : Int32,
) -> (Int32, Int32) {
  let mut i = pos
  let mut l = line
  while i < n {
    let c = cs[i]
    if c == '\n' {
      l = l + 1
      i = i + 1
    } else if c == ' ' || c == '\t' || c == '\r' {
      i = i + 1
    } else if c == '%' {
      while i < n && cs[i] != '\n' {
        i = i + 1
      }
    } else {
      break
    }
  }
  (i, l)
}

///|
/// Parses a `{...}` literal, handling nested braces and collapsing runs of
/// whitespace into one space. Edge spaces are kept so that `#` concatenation
/// behaves like BibTeX; the final value is trimmed by `parse_value`.
fn parse_braced(
  cs : Array[Char],
  n : Int32,
  pos : Int32,
  line : Int32,
) -> (String, Int32, Int32, Bool) {
  let sb = StringBuilder()
  let mut i = pos + 1
  let mut l = line
  let mut depth = 1
  let mut pending_space = false
  while i < n && depth > 0 {
    let c = cs[i]
    if c == '{' {
      if pending_space {
        sb.write_char(' ')
      }
      pending_space = false
      depth = depth + 1
      sb.write_char(c)
      i = i + 1
    } else if c == '}' {
      depth = depth - 1
      if depth > 0 {
        if pending_space {
          sb.write_char(' ')
        }
        pending_space = false
        sb.write_char(c)
      }
      i = i + 1
    } else if char_is_space(c) {
      if c == '\n' {
        l = l + 1
      }
      pending_space = true
      i = i + 1
    } else {
      if pending_space {
        sb.write_char(' ')
      }
      pending_space = false
      sb.write_char(c)
      i = i + 1
    }
  }
  (sb.to_string(), i, l, depth == 0)
}

///|
/// Parses a `"..."` literal; braces inside keep the quoted part balanced.
/// Like `parse_braced`, edge spaces survive so `#` concatenation is faithful.
fn parse_quoted(
  cs : Array[Char],
  n : Int32,
  pos : Int32,
  line : Int32,
) -> (String, Int32, Int32, Bool) {
  let sb = StringBuilder()
  let mut i = pos + 1
  let mut l = line
  let mut depth = 0
  let mut closed = false
  let mut pending_space = false
  while i < n && !closed {
    let c = cs[i]
    if c == '{' {
      if pending_space {
        sb.write_char(' ')
      }
      pending_space = false
      depth = depth + 1
      sb.write_char(c)
      i = i + 1
    } else if c == '}' && depth > 0 {
      depth = depth - 1
      if pending_space {
        sb.write_char(' ')
      }
      pending_space = false
      sb.write_char(c)
      i = i + 1
    } else if c == '"' && depth == 0 {
      closed = true
      i = i + 1
    } else if char_is_space(c) {
      if c == '\n' {
        l = l + 1
      }
      pending_space = true
      i = i + 1
    } else {
      if pending_space {
        sb.write_char(' ')
      }
      pending_space = false
      sb.write_char(c)
      i = i + 1
    }
  }
  (sb.to_string(), i, l, closed)
}

///|
/// Reads a bare token (macro name or number) up to a delimiter.
fn parse_bare(cs : Array[Char], n : Int32, pos : Int32) -> (String, Int32) {
  let mut i = pos
  while i < n {
    let c = cs[i]
    if c == ',' || c == '}' || c == ')' || c == '#' || char_is_space(c) {
      break
    }
    i = i + 1
  }
  (slice_to_string(cs, pos, i), i)
}

///|
/// Parses a BibTeX value expression: `{literal}`, `"literal"`, a macro name,
/// or several of them joined with `#`.
fn parse_value(
  cs : Array[Char],
  n : Int32,
  pos : Int32,
  line : Int32,
  macros : Map[String, String],
) -> (String, Int32, Int32, Bool) {
  let sb = StringBuilder()
  let mut i = pos
  let mut l = line
  let mut ok = true
  let mut any = false
  while true {
    let (p, nl) = skip_space(cs, n, i, l)
    i = p
    l = nl
    if i >= n {
      ok = any
      break
    }
    let c = cs[i]
    if c == '{' {
      let (text, p2, l2, good) = parse_braced(cs, n, i, l)
      sb.write_string(text)
      i = p2
      l = l2
      any = true
      if !good {
        ok = false
        break
      }
    } else if c == '"' {
      let (text, p2, l2, good) = parse_quoted(cs, n, i, l)
      sb.write_string(text)
      i = p2
      l = l2
      any = true
      if !good {
        ok = false
        break
      }
    } else {
      let (token, p2) = parse_bare(cs, n, i)
      if token == "" {
        ok = any
        break
      }
      match macros.get(lowercase(token)) {
        Some(v) => sb.write_string(v)
        None => sb.write_string(token)
      }
      i = p2
      any = true
    }
    let (p3, nl3) = skip_space(cs, n, i, l)
    i = p3
    l = nl3
    if i < n && cs[i] == '#' {
      i = i + 1
    } else {
      break
    }
  }
  (trim_ascii(sb.to_string()), i, l, ok && any)
}

///|
/// Skips to the next `@` so that a broken entry does not swallow the rest of
/// the library. Returns the new position.
fn recover_to_next_entry(cs : Array[Char], n : Int32, pos : Int32) -> Int32 {
  let mut i = pos
  while i < n && cs[i] != '@' {
    i = i + 1
  }
  i
}

///|
/// Parses the entry body once `@type{key,` has been recognised.
/// Returns `(new_pos, new_line)`.
fn parse_entry_body(
  cs : Array[Char],
  n : Int32,
  pos : Int32,
  start_line : Int32,
  entry_type : String,
  key : String,
  is_paren : Bool,
  macros : Map[String, String],
  entries : Array[BibEntry],
  errors : Array[BibParseError],
) -> (Int32, Int32) {
  let close = if is_paren { ')' } else { '}' }
  let fields : Map[String, String] = Map([])
  let mut i = pos
  let mut l = start_line
  let mut broken = false
  while i < n {
    let (p, nl) = skip_space(cs, n, i, l)
    i = p
    l = nl
    if i >= n {
      broken = true
      break
    }
    if cs[i] == close {
      i = i + 1
      break
    }
    if cs[i] == ',' {
      i = i + 1
      continue
    }
    let name_start = i
    while i < n &&
          (
            char_is_alpha(cs[i]) ||
            char_is_digit(cs[i]) ||
            cs[i] == '_' ||
            cs[i] == '-'
          ) {
      i = i + 1
    }
    let name = lowercase(slice_to_string(cs, name_start, i))
    if name.length() == 0 {
      broken = true
      break
    }
    let (p2, nl2) = skip_space(cs, n, i, l)
    i = p2
    l = nl2
    if i >= n || cs[i] != '=' {
      errors.push({ line: l, message: "字段 \{name} 缺少 = 号", })
      i = recover_to_next_entry(cs, n, i)
      broken = true
      break
    }
    i = i + 1
    let (p3, nl3) = skip_space(cs, n, i, l)
    i = p3
    l = nl3
    let (value, p4, nl4, ok) = parse_value(cs, n, i, l, macros)
    i = p4
    l = nl4
    if !ok {
      errors.push({
        line: l,
        message: "字段 \{name} 的值没有正确闭合",
      })
    }
    match fields.get(name) {
      Some(_) => ()
      None => fields.set(name, value)
    }
  }
  if broken && i >= n {
    errors.push({ line: start_line, message: "条目 \{key} 没有闭合", })
  }
  let title = match fields.get("title") {
    Some(v) => v
    None => ""
  }
  let year = match fields.get("year") {
    Some(v) => v
    None => ""
  }
  let author = match fields.get("author") {
    Some(v) => v
    None => ""
  }
  entries.push({
    key,
    entry_type,
    title,
    year,
    author,
    fields,
    line: start_line,
  })
  (i, l)
}

///|
/// Parses `@string{name = "value", ...}` definitions into the macro table.
fn parse_string_def(
  cs : Array[Char],
  n : Int32,
  pos : Int32,
  start_line : Int32,
  macros : Map[String, String],
  errors : Array[BibParseError],
) -> (Int32, Int32) {
  let mut i = pos
  let mut l = start_line
  let open = cs[i]
  let close = if open == '(' { ')' } else { '}' }
  i = i + 1
  let mut closed = false
  while i < n {
    let (p, nl) = skip_space(cs, n, i, l)
    i = p
    l = nl
    if i >= n {
      break
    }
    if cs[i] == close {
      i = i + 1
      closed = true
      break
    }
    if cs[i] == ',' {
      i = i + 1
      continue
    }
    let name_start = i
    while i < n &&
          (
            char_is_alpha(cs[i]) ||
            char_is_digit(cs[i]) ||
            cs[i] == '_' ||
            cs[i] == '-'
          ) {
      i = i + 1
    }
    let name = lowercase(slice_to_string(cs, name_start, i))
    let (p2, nl2) = skip_space(cs, n, i, l)
    i = p2
    l = nl2
    if name == "" || i >= n || cs[i] != '=' {
      errors.push({ line: l, message: "@string 定义缺少 = 号", })
      i = recover_to_next_entry(cs, n, i)
      break
    }
    i = i + 1
    let (p3, nl3) = skip_space(cs, n, i, l)
    i = p3
    l = nl3
    let (value, p4, nl4, ok) = parse_value(cs, n, i, l, macros)
    i = p4
    l = nl4
    if !ok {
      errors.push({
        line: l,
        message: "@string 宏 \{name} 的值没有正确闭合",
      })
    }
    macros.set(name, value)
  }
  if !closed {
    errors.push({ line: start_line, message: "@string 没有闭合", })
  }
  (i, l)
}

///|
/// Parses a BibTeX library into entries, macro definitions and syntax errors.
pub fn parse_bibtex(text : String) -> BibDatabase {
  let cs = text.to_array()
  let n = cs.length()
  let entries : Array[BibEntry] = []
  let errors : Array[BibParseError] = []
  let macros : Map[String, String] = Map([])
  let mut i = 0
  let mut line = 1
  while i < n {
    let c = cs[i]
    if c == '\n' {
      line = line + 1
      i = i + 1
      continue
    }
    if c == '%' {
      while i < n && cs[i] != '\n' {
        i = i + 1
      }
      continue
    }
    if c != '@' {
      i = i + 1
      continue
    }
    let entry_line = line
    i = i + 1
    let (p0, l0) = skip_space(cs, n, i, line)
    i = p0
    line = l0
    let type_start = i
    while i < n && char_is_alpha(cs[i]) {
      i = i + 1
    }
    let entry_type = lowercase(slice_to_string(cs, type_start, i))
    let (p1, l1) = skip_space(cs, n, i, line)
    i = p1
    line = l1
    if entry_type.length() == 0 {
      errors.push({
        line: entry_line,
        message: "缺少条目类型，例如 @article{...}",
      })
      i = recover_to_next_entry(cs, n, i)
      continue
    }
    if entry_type == "comment" || entry_type == "preamble" {
      if i < n && (cs[i] == '{' || cs[i] == '(') {
        let open = cs[i]
        let close = if open == '(' { ')' } else { '}' }
        let mut depth = 0
        while i < n {
          let ch = cs[i]
          if ch == '\n' {
            line = line + 1
          }
          if ch == open {
            depth = depth + 1
          } else if ch == close {
            depth = depth - 1
            if depth == 0 {
              i = i + 1
              break
            }
          }
          i = i + 1
        }
      }
      continue
    }
    if entry_type == "string" {
      if i < n && (cs[i] == '{' || cs[i] == '(') {
        let (p2, l2) = parse_string_def(cs, n, i, line, macros, errors)
        i = p2
        line = l2
      } else {
        errors.push({
          line: entry_line,
          message: "@string 后面缺少 { 或 (",
        })
        i = recover_to_next_entry(cs, n, i)
      }
      continue
    }
    if i >= n || (cs[i] != '{' && cs[i] != '(') {
      errors.push({
        line: entry_line,
        message: "条目 \{entry_type} 后面缺少 { 或 (",
      })
      i = recover_to_next_entry(cs, n, i)
      continue
    }
    let is_paren = cs[i] == '('
    let close = if is_paren { ')' } else { '}' }
    i = i + 1
    let (p2, l2) = skip_space(cs, n, i, line)
    i = p2
    line = l2
    let key_start = i
    while i < n && cs[i] != ',' && cs[i] != close && cs[i] != '\n' {
      i = i + 1
    }
    let key = trim_ascii(slice_to_string(cs, key_start, i))
    if key.length() == 0 {
      errors.push({
        line: entry_line,
        message: "条目 \{entry_type} 缺少引用键",
      })
      i = recover_to_next_entry(cs, n, i)
      continue
    }
    if i >= n || cs[i] != ',' {
      errors.push({
        line: entry_line,
        message: "条目 \{key} 的引用键后面缺少逗号",
      })
      i = recover_to_next_entry(cs, n, i)
      continue
    }
    i = i + 1
    let (p3, l3) = parse_entry_body(
      cs, n, i, entry_line, entry_type, key, is_paren, macros, entries, errors,
    )
    i = p3
    line = l3
  }
  { entries, errors, macros, }
}
