///|
fn sample_report() -> @moonbibguard.Report {
  {
    diagnostics: [
      {
        code: "MBG001",
        severity: @moonbibguard.Error,
        file: "paper.md",
        line: 3,
        column: 12,
        message: "未定义引用 attention2025",
        suggestion: Some("是否想引用 attention2024？"),
      },
    ],
    error_count: 1,
    warning_count: 0,
    info_count: 0,
    citation_count: 2,
    entry_count: 1,
  }
}

///|
test "severity labels are translated" {
  assert_eq(@moonbibguard.Error.label(), "错误")
  assert_eq(@moonbibguard.Warning.label(), "警告")
  assert_eq(@moonbibguard.Info.label(), "提示")
}

///|
test "severity json tags are stable" {
  assert_eq(@moonbibguard.Error.tag(), "error")
  assert_eq(@moonbibguard.Warning.tag(), "warning")
  assert_eq(@moonbibguard.Info.tag(), "info")
}

///|
test "empty report says nothing was found" {
  let report : @moonbibguard.Report = {
    diagnostics: [],
    error_count: 0,
    warning_count: 0,
    info_count: 0,
    citation_count: 0,
    entry_count: 0,
  }
  let text = @moonbibguard.format_report(report)
  assert_true(text.contains("没有发现问题"))
}

///|
test "report text contains code and position" {
  let text = @moonbibguard.format_report(sample_report())
  assert_true(text.contains("MBG001"))
  assert_true(text.contains("paper.md:3:12"))
}

///|
test "report text contains the suggestion line" {
  let text = @moonbibguard.format_report(sample_report())
  assert_true(text.contains("建议："))
}

///|
test "json report contains summary and code" {
  let json = @moonbibguard.to_json(sample_report())
  assert_true(json.contains("\"errors\": 1"))
  assert_true(json.contains("\"code\": \"MBG001\""))
}

///|
test "json report escapes double quotes" {
  let report : @moonbibguard.Report = {
    diagnostics: [
      {
        code: "MBG001",
        severity: @moonbibguard.Error,
        file: "a.md",
        line: 1,
        column: 1,
        message: "say \"hi\"",
        suggestion: None,
      },
    ],
    error_count: 1,
    warning_count: 0,
    info_count: 0,
    citation_count: 1,
    entry_count: 0,
  }
  let json = @moonbibguard.to_json(report)
  assert_true(json.contains("say \\\"hi\\\""))
}

///|
test "json report omits suggestion when absent" {
  let report : @moonbibguard.Report = {
    diagnostics: [
      {
        code: "MBG003",
        severity: @moonbibguard.Warning,
        file: "b.bib",
        line: 2,
        column: 0,
        message: "unused",
        suggestion: None,
      },
    ],
    error_count: 0,
    warning_count: 1,
    info_count: 0,
    citation_count: 1,
    entry_count: 2,
  }
  let json = @moonbibguard.to_json(report)
  assert_true(!json.contains("suggestion"))
}

///|
test "json report keeps suggestion when present" {
  let json = @moonbibguard.to_json(sample_report())
  assert_true(json.contains("suggestion"))
}
