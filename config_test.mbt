///|
test "default config keeps no overrides" {
  let config = @moonbibguard.default_config()
  assert_eq(config.rules.length(), 0)
  assert_eq(config.format, "")
  assert_eq(config.strict, false)
  assert_eq(config.bib, "")
}

///|
test "empty object parses to defaults without complaints" {
  let (config, problem) = @moonbibguard.parse_config("{}")
  assert_eq(config.rules.length(), 0)
  assert_true(problem is None)
}

///|
test "rules, format and bib fields are read" {
  let (config, problem) = @moonbibguard.parse_config(
    "{\"format\":\"sarif\",\"strict\":true,\"bib\":\"refs/lib.bib\",\"rules\":{\"MBG003\":\"off\"}}",
  )
  assert_true(problem is None)
  assert_eq(config.format, "sarif")
  assert_eq(config.strict, true)
  assert_eq(config.bib, "refs/lib.bib")
  assert_eq(config.rules.get("MBG003").unwrap(), "off")
}

///|
test "rule set to off removes its diagnostics and recount works" {
  let report = @moonbibguard.analyze("[@ghost]", "@misc{lonely, title = {L}}")
  let (config, _) = @moonbibguard.parse_config(
    "{\"rules\":{\"MBG003\":\"off\"}}",
  )
  let filtered = @moonbibguard.apply_config(report, config)
  assert_eq(filtered.diagnostics.length(), 1)
  assert_eq(filtered.error_count, 1)
  assert_eq(filtered.warning_count, 0)
}

///|
test "severity override rewrites the level and counters" {
  let report = @moonbibguard.analyze(
    "[@ok]", "@misc{ok, title = {OK}}\n@misc{unused, title = {U}}",
  )
  assert_eq(report.warning_count, 1)
  let (config, _) = @moonbibguard.parse_config(
    "{\"rules\":{\"MBG003\":\"error\"}}",
  )
  let strict_report = @moonbibguard.apply_config(report, config)
  assert_eq(strict_report.error_count, 1)
  assert_eq(strict_report.warning_count, 0)
}

///|
test "unknown rule level reports a problem and keeps defaults" {
  let (config, problem) = @moonbibguard.parse_config(
    "{\"rules\":{\"MBG002\":\"fatal\"}}",
  )
  assert_true(problem is Some(_))
  assert_eq(config.rules.length(), 0)
}

///|
test "malformed json falls back to defaults" {
  let (config, problem) = @moonbibguard.parse_config("{ rules: ")
  assert_true(problem is Some(_))
  assert_eq(config.rules.length(), 0)
}

///|
test "non-object json is rejected" {
  let (_, problem) = @moonbibguard.parse_config("[\"MBG003\"]")
  assert_true(problem is Some(_))
}

///|
test "utf-8 bom is tolerated" {
  let (config, problem) = @moonbibguard.parse_config(
    "\u{FEFF}{\"format\":\"json\"}",
  )
  assert_true(problem is None)
  assert_eq(config.format, "json")
}

///|
test "applying an empty config changes nothing" {
  let report = @moonbibguard.analyze("[@ghost]", "@misc{lonely, title = {L}}")
  let same = @moonbibguard.apply_config(report, @moonbibguard.default_config())
  assert_eq(same.diagnostics.length(), report.diagnostics.length())
  assert_eq(same.error_count, report.error_count)
  assert_eq(same.warning_count, report.warning_count)
}
