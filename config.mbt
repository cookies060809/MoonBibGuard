// Project configuration: `.moonbibguard.json`.
//
// The config file is optional. Parse failures never abort a run: the caller
// gets the defaults plus a message to print, so a typo in the config cannot
// take down CI.

///|
/// Per-rule override: `"off"` drops the diagnostic, `"error" | "warning" |
/// "info"` rewrites its severity.
pub(all) struct Config {
  rules : Map[String, String]
  format : String
  strict : Bool
  bib : String
}

///|
pub fn default_config() -> Config {
  { rules: Map([]), format: "", strict: false, bib: "", }
}

///|
fn json_string_field(obj : Map[String, @json.Json], key : String) -> String? {
  match obj.get(key) {
    Some(@json.Json::String(s)) => Some(s)
    _ => None
  }
}

///|
fn json_bool_field(obj : Map[String, @json.Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(@json.Json::True) => Some(true)
    Some(@json.Json::False) => Some(false)
    _ => None
  }
}

///|
/// Drops a leading UTF-8 BOM, which Windows editors and `Set-Content -Encoding
/// UTF8` add silently. Without this, a hand-written config would fail to parse.
fn strip_bom(text : String) -> String {
  let cs = text.to_array()
  if cs.length() > 0 && cs[0] == '\u{FEFF}' {
    slice_to_string(cs, 1, cs.length())
  } else {
    text
  }
}

///|
/// Parses `.moonbibguard.json`. Returns the config plus an optional problem
/// description; on a fatal problem the returned config is the default one.
pub fn parse_config(text : String) -> (Config, String?) {
  let json = @json.parse(strip_bom(text)) catch {
    _ =>
      return (
        default_config(),
        Some("配置文件不是合法 JSON，已忽略"),
      )
  }
  let obj = match json {
    @json.Json::Object(m) => m
    _ =>
      return (
        default_config(),
        Some("配置文件的顶层必须是 JSON 对象，已忽略"),
      )
  }
  let mut format = ""
  let mut bib = ""
  let mut strict = false
  match json_string_field(obj, "bib") {
    Some(v) => bib = v
    None => ()
  }
  match json_string_field(obj, "format") {
    Some(v) => format = v
    None => ()
  }
  match json_bool_field(obj, "strict") {
    Some(v) => strict = v
    None => ()
  }
  let rules : Map[String, String] = Map([])
  let mut problem : String? = None
  match obj.get("rules") {
    Some(@json.Json::Object(table)) =>
      table.each(fn(key, value) {
        match value {
          @json.Json::String(level) => {
            let lower = lowercase(level)
            if lower == "off" ||
              lower == "error" ||
              lower == "warning" ||
              lower == "info" {
              rules.set(key, lower)
            } else {
              problem = Some(
                "规则 \{key} 的级别 \{level} 无法识别，可用 off/error/warning/info",
              )
            }
          }
          _ =>
            problem = Some(
              "规则 \{key} 的级别必须是字符串（off/error/warning/info）",
            )
        }
      })
    Some(_) =>
      problem = Some("rules 必须是对象，例如 {\"MBG003\": \"off\"}")
    None => ()
  }
  ({ rules, format, strict, bib, }, problem)
}

///|
fn severity_from_tag(tag : String) -> Severity? {
  match tag {
    "error" => Some(Error)
    "warning" => Some(Warning)
    "info" => Some(Info)
    _ => None
  }
}

///|
/// Applies rule overrides to a report: drops `off` rules and rewrites severity
/// for the rest, then recomputes the counters so JSON/SARIF stay consistent.
pub fn apply_config(report : Report, config : Config) -> Report {
  let diags : Array[Diagnostic] = []
  let mut errors = 0
  let mut warnings = 0
  let mut infos = 0
  for d in report.diagnostics {
    let mut level = d.severity
    let mut keep = true
    match config.rules.get(d.code) {
      Some("off") => keep = false
      Some(tag) =>
        match severity_from_tag(tag) {
          Some(sev) => level = sev
          None => ()
        }
      _ => ()
    }
    if keep {
      diags.push({
        code: d.code,
        severity: level,
        file: d.file,
        line: d.line,
        column: d.column,
        message: d.message,
        suggestion: d.suggestion,
      })
      match level {
        Error => errors = errors + 1
        Warning => warnings = warnings + 1
        Info => infos = infos + 1
      }
    }
  }
  {
    diagnostics: diags,
    error_count: errors,
    warning_count: warnings,
    info_count: infos,
    citation_count: report.citation_count,
    entry_count: report.entry_count,
  }
}
