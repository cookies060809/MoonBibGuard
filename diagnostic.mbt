///|
/// How serious a diagnostic is.
pub(all) enum Severity {
  Error
  Warning
  Info
}

///|
/// One finding produced by the analyzer.
pub(all) struct Diagnostic {
  code : String
  severity : Severity
  file : String
  line : Int32
  column : Int32
  message : String
  suggestion : String?
}

///|
/// Aggregated result of one analysis run.
pub(all) struct Report {
  diagnostics : Array[Diagnostic]
  error_count : Int32
  warning_count : Int32
  info_count : Int32
  citation_count : Int32
  entry_count : Int32
}

///|
pub fn Severity::label(self : Severity) -> String {
  match self {
    Error => "错误"
    Warning => "警告"
    Info => "提示"
  }
}

///|
pub fn Severity::tag(self : Severity) -> String {
  match self {
    Error => "error"
    Warning => "warning"
    Info => "info"
  }
}

///|
fn json_escape(s : String) -> String {
  let sb = StringBuilder()
  for c in s {
    if c == '"' {
      sb.write_string("\\\"")
    } else if c == '\\' {
      sb.write_string("\\\\")
    } else if c == '\n' {
      sb.write_string("\\n")
    } else if c == '\r' {
      sb.write_string("\\r")
    } else if c == '\t' {
      sb.write_string("\\t")
    } else {
      sb.write_char(c)
    }
  }
  sb.to_string()
}

///|
/// Renders the report as human-readable terminal text.
pub fn format_report(
  report : Report,
  markdown_file~ : String = "paper.md",
  bib_file~ : String = "references.bib",
) -> String {
  let sb = StringBuilder()
  sb.write_string("MoonBibGuard 引用一致性检查\n")
  sb.write_string("  正文：\{markdown_file}\n")
  sb.write_string("  文献库：\{bib_file}\n")
  sb.write_string("--------------------------------\n")
  for d in report.diagnostics {
    if d.column > 0 {
      sb.write_string(
        "[\{d.severity.label()}] \{d.code} \{d.file}:\{d.line}:\{d.column}  \{d.message}\n",
      )
    } else {
      sb.write_string(
        "[\{d.severity.label()}] \{d.code} \{d.file}:\{d.line}  \{d.message}\n",
      )
    }
    match d.suggestion {
      Some(s) => sb.write_string("         建议：\{s}\n")
      None => ()
    }
  }
  if report.diagnostics.length() == 0 {
    sb.write_string("没有发现问题。\n")
  }
  sb.write_string("--------------------------------\n")
  sb.write_string(
    "检查完成：\{report.error_count} 个错误 · \{report.warning_count} 个警告 · \{report.info_count} 条提示\n",
  )
  sb.write_string(
    "统计：\{report.citation_count} 条正文引用 · \{report.entry_count} 条 BibTeX 文献\n",
  )
  sb.to_string()
}

///|
/// Renders the report as a stable, machine-readable JSON document.
pub fn to_json(report : Report) -> String {
  let sb = StringBuilder()
  sb.write_string("{\n")
  sb.write_string("  \"tool\": \"moonbibguard\",\n")
  sb.write_string("  \"summary\": {\n")
  sb.write_string("    \"errors\": \{report.error_count},\n")
  sb.write_string("    \"warnings\": \{report.warning_count},\n")
  sb.write_string("    \"infos\": \{report.info_count},\n")
  sb.write_string("    \"diagnostics\": \{report.diagnostics.length()},\n")
  sb.write_string("    \"citations\": \{report.citation_count},\n")
  sb.write_string("    \"entries\": \{report.entry_count}\n")
  sb.write_string("  },\n")
  sb.write_string("  \"diagnostics\": [")
  let mut first = true
  for d in report.diagnostics {
    if first {
      sb.write_string("\n")
      first = false
    } else {
      sb.write_string(",\n")
    }
    sb.write_string("    {")
    sb.write_string("\"code\": \"\{json_escape(d.code)}\", ")
    sb.write_string("\"severity\": \"\{d.severity.tag()}\", ")
    sb.write_string("\"file\": \"\{json_escape(d.file)}\", ")
    sb.write_string("\"line\": \{d.line}, ")
    sb.write_string("\"column\": \{d.column}, ")
    sb.write_string("\"message\": \"\{json_escape(d.message)}\"")
    match d.suggestion {
      Some(s) => sb.write_string(", \"suggestion\": \"\{json_escape(s)}\"")
      None => ()
    }
    sb.write_string("}")
  }
  if !first {
    sb.write_string("\n  ")
  }
  sb.write_string("]\n")
  sb.write_string("}\n")
  sb.to_string()
}
