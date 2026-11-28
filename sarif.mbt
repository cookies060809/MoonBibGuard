// SARIF 2.1.0 output.
//
// SARIF is what code-scanning platforms consume, so this is the format that
// lets MoonBibGuard push its findings into an existing CI pipeline instead of
// only printing to a terminal.

///|
fn sarif_rule_id(code : String) -> String {
  match code {
    "MBG001" => "undefined-citation"
    "MBG002" => "duplicate-key"
    "MBG003" => "unused-entry"
    "MBG004" => "missing-field"
    "MBG005" => "bibtex-syntax"
    _ => "unknown-rule"
  }
}

///|
fn sarif_rule_index(code : String) -> Int32 {
  match code {
    "MBG001" => 0
    "MBG002" => 1
    "MBG003" => 2
    "MBG004" => 3
    "MBG005" => 4
    _ => 5
  }
}

///|
fn sarif_level(sev : Severity) -> String {
  match sev {
    Error => "error"
    Warning => "warning"
    Info => "note"
  }
}

///|
fn sarif_help_uri(code : String) -> String {
  "https://github.com/cookies060809/MoonBibGuard/blob/main/docs/rules.md#\{lowercase(code)}"
}

///|
fn sarif_rule(code : String, desc : String, level : String) -> String {
  "{\"id\":\"\{code}\",\"name\":\"\{sarif_rule_id(code)}\",\"shortDescription\":{\"text\":\"\{json_escape(desc)}\"},\"defaultConfiguration\":{\"level\":\"\{level}\"},\"helpUri\":\"\{sarif_help_uri(code)}\"}"
}

///|
fn sarif_rules() -> String {
  let sb = StringBuilder()
  sb.write_string("      \"rules\": [\n")
  sb.write_string("        ")
  sb.write_string(
    sarif_rule(
      "MBG001", "正文引用的键在 BibTeX 文献库中不存在", "error",
    ),
  )
  sb.write_string(",\n        ")
  sb.write_string(
    sarif_rule(
      "MBG002", "同一引用键被多个 BibTeX 条目重复定义", "error",
    ),
  )
  sb.write_string(",\n        ")
  sb.write_string(
    sarif_rule(
      "MBG003", "文献库中的条目在正文里从未被引用", "warning",
    ),
  )
  sb.write_string(",\n        ")
  sb.write_string(
    sarif_rule("MBG004", "条目按其类型缺少必需字段", "warning"),
  )
  sb.write_string(",\n        ")
  sb.write_string(
    sarif_rule(
      "MBG005", "BibTeX 语法错误（值未闭合、字段缺 = 等）", "error",
    ),
  )
  sb.write_string("\n      ]\n")
  sb.to_string()
}

///|
fn sarif_location(d : Diagnostic) -> String {
  let uri = json_escape(slash_path(d.file))
  let region = if d.column > 0 {
    "\"startLine\":\{d.line},\"startColumn\":\{d.column}"
  } else {
    "\"startLine\":\{d.line}"
  }
  "{\"physicalLocation\":{\"artifactLocation\":{\"uri\":\"\{uri}\"},\"region\":{\{region}}}}"
}

///|
fn sarif_result(d : Diagnostic) -> String {
  let sb = StringBuilder()
  sb.write_string("    {\n")
  sb.write_string("      \"ruleId\": \"\{d.code}\",\n")
  sb.write_string("      \"ruleIndex\": \{sarif_rule_index(d.code)},\n")
  sb.write_string("      \"level\": \"\{sarif_level(d.severity)}\",\n")
  sb.write_string(
    "      \"message\": {\"text\": \"\{json_escape(d.message)}\"},\n",
  )
  match d.suggestion {
    Some(s) =>
      sb.write_string(
        "      \"fixes\": [{\"description\": {\"text\": \"\{json_escape(s)}\"}}],\n",
      )
    None => ()
  }
  sb.write_string("      \"locations\": [\{sarif_location(d)}]\n")
  sb.write_string("    }")
  sb.to_string()
}

///|
/// Renders the report as SARIF 2.1.0, consumable by code-scanning dashboards.
/// `tool_version~` is stamped into `tool.driver.version`.
pub fn to_sarif(report : Report, tool_version~ : String = version()) -> String {
  let sb = StringBuilder()
  sb.write_string("{\n")
  sb.write_string(
    "  \"$schema\": \"https://json.schemastore.org/sarif-2.1.0.json\",\n",
  )
  sb.write_string("  \"version\": \"2.1.0\",\n")
  sb.write_string("  \"runs\": [\n")
  sb.write_string("    {\n")
  sb.write_string("      \"tool\": {\n")
  sb.write_string("        \"driver\": {\n")
  sb.write_string("          \"name\": \"MoonBibGuard\",\n")
  sb.write_string(
    "          \"informationUri\": \"https://github.com/cookies060809/MoonBibGuard\",\n",
  )
  sb.write_string("          \"version\": \"\{json_escape(tool_version)}\",\n")
  sb.write_string(sarif_rules())
  sb.write_string("        }\n")
  sb.write_string("      },\n")
  sb.write_string("      \"results\": [\n")
  let mut first = true
  for d in report.diagnostics {
    if first {
      first = false
    } else {
      sb.write_string(",\n")
    }
    sb.write_string("    ")
    sb.write_string(sarif_result(d))
  }
  if !first {
    sb.write_string("\n")
  }
  sb.write_string("      ],\n")
  let ok_flag = if report.error_count > 0 { "false" } else { "true" }
  sb.write_string(
    "      \"invocations\": [{\"executionSuccessful\": \{ok_flag}}],\n",
  )
  sb.write_string(
    "      \"properties\": {\"errorCount\": \{report.error_count}, \"warningCount\": \{report.warning_count}, \"infoCount\": \{report.info_count}, \"citationCount\": \{report.citation_count}, \"entryCount\": \{report.entry_count}}\n",
  )
  sb.write_string("    }\n")
  sb.write_string("  ]\n")
  sb.write_string("}\n")
  sb.to_string()
}
