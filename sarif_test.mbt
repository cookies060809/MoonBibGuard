///|
test "sarif header declares 2.1.0 and the schema" {
  let report = @moonbibguard.analyze("[@ghost]", "@misc{lonely, title = {L}}")
  let sarif = @moonbibguard.to_sarif(report)
  assert_true(sarif.contains("\"version\": \"2.1.0\""))
  assert_true(sarif.contains("sarif-2.1.0.json"))
  assert_true(sarif.contains("\"name\": \"MoonBibGuard\""))
}

///|
test "sarif declares all five rules" {
  let report = @moonbibguard.analyze("[@ok]", "@misc{ok, title = {OK}}")
  let sarif = @moonbibguard.to_sarif(report)
  assert_true(sarif.contains("\"id\":\"MBG001\""))
  assert_true(sarif.contains("\"id\":\"MBG005\""))
  assert_true(sarif.contains("undefined-citation"))
  assert_true(sarif.contains("bibtex-syntax"))
}

///|
test "sarif results carry rule id, level and location" {
  let report = @moonbibguard.analyze(
    "正文 [@ghost]",
    "@misc{ok, title = {OK}}",
    markdown_file="chapter.md",
    bib_file="refs.bib",
  )
  let sarif = @moonbibguard.to_sarif(report)
  assert_true(sarif.contains("\"ruleId\": \"MBG001\""))
  assert_true(sarif.contains("\"level\": \"error\""))
  assert_true(sarif.contains("\"uri\":\"chapter.md\""))
  assert_true(sarif.contains("\"startLine\":1"))
  assert_true(sarif.contains("\"level\": \"warning\""))
}

///|
test "sarif marks the run unsuccessful when errors exist" {
  let failing = @moonbibguard.analyze("[@ghost]", "@misc{ok, title = {OK}}")
  assert_true(
    @moonbibguard.to_sarif(failing).contains("\"executionSuccessful\": false"),
  )
  let clean = @moonbibguard.analyze("[@ok]", "@misc{ok, title = {OK}}")
  assert_true(
    @moonbibguard.to_sarif(clean).contains("\"executionSuccessful\": true"),
  )
}

///|
test "sarif keeps windows paths as forward-slash uris" {
  let report = @moonbibguard.analyze(
    "正文 [@ghost]",
    "@misc{ok, title = {OK}}",
    markdown_file="docs\\ch1.md",
  )
  let sarif = @moonbibguard.to_sarif(report)
  assert_true(sarif.contains("\"uri\":\"docs/ch1.md\""))
  assert_true(!sarif.contains("docs\\\\ch1.md"))
}

///|
test "sarif summary properties match the report counters" {
  let report = @moonbibguard.analyze("[@ghost]", "@misc{lonely, title = {L}}")
  let sarif = @moonbibguard.to_sarif(report)
  assert_true(sarif.contains("\"errorCount\": 1"))
  assert_true(sarif.contains("\"warningCount\": 1"))
}
