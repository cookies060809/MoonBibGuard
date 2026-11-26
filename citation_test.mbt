///|
test "single citation is extracted" {
  let cites = @moonbibguard.extract_citations(
    "Transformer was proposed [@vaswani2017].",
  )
  assert_eq(cites.length(), 1)
  assert_eq(cites[0].key, "vaswani2017")
}

///|
test "two citations in one bracket are extracted" {
  let cites = @moonbibguard.extract_citations("Both [@a1; @b2] are cited.")
  assert_eq(cites.length(), 2)
  assert_eq(cites[0].key, "a1")
  assert_eq(cites[1].key, "b2")
}

///|
test "negative citation marker is accepted" {
  let cites = @moonbibguard.extract_citations("Only the year [-@neg1].")
  assert_eq(cites.length(), 1)
  assert_eq(cites[0].key, "neg1")
}

///|
test "locator after comma is not part of the key" {
  let cites = @moonbibguard.extract_citations("See [@key1, p. 33] for details.")
  assert_eq(cites.length(), 1)
  assert_eq(cites[0].key, "key1")
}

///|
test "citation column points at the key" {
  let cites = @moonbibguard.extract_citations("Text [@key].")
  assert_eq(cites[0].column, 8)
}

///|
test "line numbers are tracked across lines" {
  let cites = @moonbibguard.extract_citations("line one\nline [@second] two")
  assert_eq(cites.length(), 1)
  assert_eq(cites[0].line, 2)
}

///|
test "fenced code block is skipped" {
  let cites = @moonbibguard.extract_citations("```md\n[@hidden]\n```")
  assert_eq(cites.length(), 0)
}

///|
test "inline code span is skipped" {
  let cites = @moonbibguard.extract_citations("Example `[@also_hidden]` here.")
  assert_eq(cites.length(), 0)
}

///|
test "plain markdown link is not a citation" {
  let cites = @moonbibguard.extract_citations(
    "See [the guide](https://example.com).",
  )
  assert_eq(cites.length(), 0)
}

///|
test "email address is not a citation" {
  let cites = @moonbibguard.extract_citations(
    "Contact me at someone@example.com anytime.",
  )
  assert_eq(cites.length(), 0)
}

///|
test "unclosed fence swallows the rest of the file" {
  let cites = @moonbibguard.extract_citations("```\n[@inside]")
  assert_eq(cites.length(), 0)
}

///|
test "citation after a closed fence is detected again" {
  let cites = @moonbibguard.extract_citations(
    "```\n[@inside]\n```\nReal [@outside]",
  )
  assert_eq(cites.length(), 1)
  assert_eq(cites[0].key, "outside")
}

///|
test "multiple citations on one line keep order" {
  let cites = @moonbibguard.extract_citations("A [@one] and B [@two].")
  assert_eq(cites.length(), 2)
  assert_eq(cites[0].key, "one")
  assert_eq(cites[1].key, "two")
}

///|
test "keys with dots dashes and colons are accepted" {
  let cites = @moonbibguard.extract_citations("[@a.b-c:1]")
  assert_eq(cites[0].key, "a.b-c:1")
}

///|
test "brackets without at-sign are ignored" {
  let cites = @moonbibguard.extract_citations("An array [0] and a list [a, b].")
  assert_eq(cites.length(), 0)
}
