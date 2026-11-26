// Node.js bridge: MoonBit owns all analysis, Node only does file and argv I/O.

///|
extern "js" fn js_argv() -> FixedArray[String] =
  #| () => process.argv.slice(2)

///|
extern "js" fn js_exists(path : String) -> Bool =
  #| (p) => {
  #|   try {
  #|     const fs = process.getBuiltinModule ? process.getBuiltinModule("node:fs") : require("node:fs");
  #|     return fs.existsSync(p);
  #|   } catch (e) {
  #|     return false;
  #|   }
  #| }

///|
extern "js" fn js_read(path : String) -> String =
  #| (p) => {
  #|   try {
  #|     const fs = process.getBuiltinModule ? process.getBuiltinModule("node:fs") : require("node:fs");
  #|     return fs.readFileSync(p, "utf8");
  #|   } catch (e) {
  #|     return "";
  #|   }
  #| }

///|
extern "js" fn js_write(path : String, text : String) -> Bool =
  #| (p, t) => {
  #|   try {
  #|     const fs = process.getBuiltinModule ? process.getBuiltinModule("node:fs") : require("node:fs");
  #|     fs.writeFileSync(p, t, "utf8");
  #|     return true;
  #|   } catch (e) {
  #|     return false;
  #|   }
  #| }

///|
extern "js" fn js_set_exit_code(code : Int32) -> Unit =
  #| (c) => { process.exitCode = c; }

///|
extern "js" fn js_print(text : String) -> Unit =
  #| (t) => { process.stdout.write(t); }

///|
fn print_banner() -> Unit {
  println(
    "MoonBibGuard \{@moonbibguard.version()} — Markdown + BibTeX 引用一致性检查",
  )
}

///|
fn print_usage() -> Unit {
  print_banner()
  println("")
  println("用法：")
  println("  node mbg.js <paper.md> <references.bib> [选项]")
  println("  node mbg.js examples/paper.md examples/references.bib")
  println("")
  println("选项：")
  println("  --json              以 JSON 输出诊断报告")
  println("  -o, --output <文件>  把报告写入文件")
  println("  --quiet             只输出统计行")
  println("  -h, --help          显示帮助")
  println("  -v, --version       显示版本")
  println("")
  println(
    "退出码：0 无错误；1 存在错误级诊断；2 参数或文件问题",
  )
}

///|
fn main {
  let args = js_argv()
  let mut md_file = ""
  let mut bib_file = ""
  let mut as_json = false
  let mut quiet = false
  let mut output = ""
  let mut bad_args = false
  let mut i = 0
  while i < args.length() {
    let a = args[i]
    if a == "--json" {
      as_json = true
    } else if a == "--quiet" {
      quiet = true
    } else if a == "-h" || a == "--help" {
      print_usage()
      return
    } else if a == "-v" || a == "--version" {
      println("moonbibguard \{@moonbibguard.version()}")
      return
    } else if a == "-o" || a == "--output" {
      if i + 1 < args.length() {
        output = args[i + 1]
        i = i + 1
      } else {
        bad_args = true
      }
    } else if a.has_prefix("-") {
      println("未知参数：\{a}")
      bad_args = true
    } else if md_file == "" {
      md_file = a
    } else if bib_file == "" {
      bib_file = a
    } else {
      println("多余的参数：\{a}")
      bad_args = true
    }
    i = i + 1
  }
  if bad_args {
    println("")
    print_usage()
    js_set_exit_code(2)
    return
  }
  if md_file == "" || bib_file == "" {
    println(
      "需要同时给出 Markdown 正文和 BibTeX 文献库两个路径。",
    )
    println("")
    print_usage()
    js_set_exit_code(2)
    return
  }
  if !js_exists(md_file) {
    println("找不到 Markdown 文件：\{md_file}")
    js_set_exit_code(2)
    return
  }
  if !js_exists(bib_file) {
    println("找不到 BibTeX 文件：\{bib_file}")
    js_set_exit_code(2)
    return
  }
  let md_text = js_read(md_file)
  let bib_text = js_read(bib_file)
  let report = @moonbibguard.analyze(
    md_text,
    bib_text,
    markdown_file=md_file,
    bib_file~,
  )
  let text = if as_json {
    @moonbibguard.to_json(report)
  } else if quiet {
    "检查完成：\{report.error_count} 个错误 · \{report.warning_count} 个警告"
  } else {
    @moonbibguard.format_report(report, markdown_file=md_file, bib_file~)
  }
  if output != "" {
    if js_write(output, text) {
      println("报告已写入 \{output}")
    } else {
      println("无法写入 \{output}")
      js_set_exit_code(2)
    }
  } else {
    js_print(text)
  }
  if report.error_count > 0 {
    js_set_exit_code(1)
  } else {
    js_set_exit_code(0)
  }
}
