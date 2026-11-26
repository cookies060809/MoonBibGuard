///|
/// One citation key found in Markdown text, with its source location.
pub(all) struct Citation {
  key : String
  line : Int32
  column : Int32
}

///|
fn first_non_space(cs : Array[Char], start : Int32, stop : Int32) -> Int32 {
  let mut i = start
  while i < stop && (cs[i] == ' ' || cs[i] == '\t' || cs[i] == '\r') {
    i = i + 1
  }
  i
}

///|
/// Detects a fenced code block marker (``` or ~~~) allowing leading spaces.
fn is_fence_line(cs : Array[Char], start : Int32, stop : Int32) -> Bool {
  let i = first_non_space(cs, start, stop)
  if stop - i < 3 {
    return false
  }
  let c = cs[i]
  if c != '`' && c != '~' {
    return false
  }
  cs[i + 1] == c && cs[i + 2] == c
}

///|
/// Extracts citation keys from one bracket group such as `[@a; @b, p. 3]`.
fn scan_bracket_group(
  cs : Array[Char],
  start : Int32,
  stop : Int32,
  line_no : Int32,
  line_start : Int32,
  out : Array[Citation],
) -> Unit {
  let mut seg_start = start
  let mut i = start
  while i <= stop {
    if i == stop || cs[i] == ';' {
      let seg_stop = i
      let mut j = seg_start
      let mut at = -1
      while j < seg_stop {
        if cs[j] == '@' {
          at = j
          break
        }
        j = j + 1
      }
      if at >= 0 {
        let key_start = at + 1
        let mut key_end = key_start
        while key_end < seg_stop && char_is_key_body(cs[key_end]) {
          key_end = key_end + 1
        }
        if key_end > key_start {
          let key = slice_to_string(cs, key_start, key_end)
          out.push({ key, line: line_no, column: key_start - line_start + 1, })
        }
      }
      seg_start = i + 1
    }
    i = i + 1
  }
}

///|
/// Scans a single Markdown line, skipping inline code spans.
fn scan_markdown_line(
  cs : Array[Char],
  start : Int32,
  stop : Int32,
  line_no : Int32,
  out : Array[Citation],
) -> Unit {
  let mut i = start
  let mut in_code = false
  while i < stop {
    let c = cs[i]
    if c == '`' {
      in_code = !in_code
      i = i + 1
      continue
    }
    if in_code {
      i = i + 1
      continue
    }
    if c == '[' {
      let mut j = i + 1
      let mut depth = 1
      let mut found = -1
      while j < stop {
        if cs[j] == '[' {
          depth = depth + 1
        } else if cs[j] == ']' {
          depth = depth - 1
          if depth == 0 {
            found = j
            break
          }
        }
        j = j + 1
      }
      if found >= 0 {
        scan_bracket_group(cs, i + 1, found, line_no, start, out)
        i = found + 1
        continue
      }
    }
    i = i + 1
  }
}

///|
/// Extracts Pandoc-style citations (`[@key]`, `[@a; @b]`, `[-@key]`) from
/// Markdown, skipping fenced code blocks and inline code spans.
pub fn extract_citations(text : String) -> Array[Citation] {
  let cs = text.to_array()
  let n = cs.length()
  let out : Array[Citation] = []
  let mut pos = 0
  let mut line_no = 1
  let mut in_fence = false
  while pos < n {
    let mut end = pos
    while end < n && cs[end] != '\n' {
      end = end + 1
    }
    if is_fence_line(cs, pos, end) {
      in_fence = !in_fence
    } else if !in_fence {
      scan_markdown_line(cs, pos, end, line_no, out)
    }
    pos = end + 1
    line_no = line_no + 1
  }
  out
}
