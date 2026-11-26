// Node.js bridge: MoonBit owns all analysis, Node only does argv and file I/O.

///|
extern "js" fn js_argv() -> FixedArray[String] =
  #| () => process.argv.slice(2)

///|
#borrow(path)
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
#borrow(path)
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
#borrow(path, text)
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
#borrow(text)
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
  println("  node main.js <paper.md> <references.bib> [选项]")
  println(
    "  node main.js <章节1.md> <章节2.md> --bib references.bib [选项]",
  )
  println("  node main.js examples/paper.md examples/references.bib")
  println("")
  println("选项：")
  println(
    "  --bib <文件>         显式指定文献库，可一次检查多个 Markdown",
  )
  println("  --json              以 JSON 输出诊断报告")
  println("  --format <格式>     text（默认）、json 或 github")
  println("  -o, --output <文件>  把报告写入文件")
  println("  --strict            警告也视为失败（退出码 1）")
  println("  --quiet             只输出统计行")
  println("  -h, --help          显示帮助")
  println("  -v, --version       显示版本")
  println("")
  println(
    "退出码：0 无错误；1 存在错误级诊断或 --strict 下的警告；2 参数或文件问题",
  )
}

///|
fn join_files(files : Array[String]) -> String {
  let sb = StringBuilder()
  let mut first = true
  for f in files {
    if first {
      first = false
    } else {
      sb.write_string(", ")
    }
    sb.write_string(@moonbibguard.slash_path(f))
  }
  sb.to_string()
}

///|
fn main {
  let args = js_argv()
  let mut md_files : Array[String] = []
  let mut bib_file = ""
  let mut bib_given = false
  let mut format = "text"
  let mut quiet = false
  let mut strict = false
  let mut output = ""
  let mut bad_args = false
  let mut i = 0
  while i < args.length() {
    let a = args[i]
    if a == "--json" {
      format = "json"
    } else if a == "--quiet" {
      quiet = true
    } else if a == "--strict" {
      strict = true
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
    } else if a == "--bib" {
      if i + 1 < args.length() {
        bib_file = args[i + 1]
        bib_given = true
        i = i + 1
      } else {
        bad_args = true
      }
    } else if a == "--format" {
      if i + 1 < args.length() {
        format = args[i + 1]
        i = i + 1
      } else {
        bad_args = true
      }
    } else if a.has_prefix("-") {
      println("未知参数：\{a}")
      bad_args = true
    } else {
      md_files.push(a)
    }
    i = i + 1
  }
  if bad_args {
    println("")
    print_usage()
    js_set_exit_code(2)
    return
  }
  if !bib_given {
    if md_files.length() == 2 {
      bib_file = md_files[1]
      md_files = [md_files[0]]
    } else if md_files.length() == 1 {
      bib_file = "references.bib"
    } else if md_files.length() > 2 {
      println(
        "一次检查多个 Markdown 文件时，请用 --bib 显式指定文献库。",
      )
      println("")
      print_usage()
      js_set_exit_code(2)
      return
    }
  }
  if md_files.length() == 0 || bib_file == "" {
    println("需要给出 Markdown 正文和 BibTeX 文献库路径。")
    println("")
    print_usage()
    js_set_exit_code(2)
    return
  }
  if format != "text" && format != "json" && format != "github" {
    println("未知输出格式：\{format}，可用 text / json / github。")
    js_set_exit_code(2)
    return
  }
  let mut missing = ""
  for f in md_files {
    if !js_exists(f) {
      missing = f
    }
  }
  if missing != "" {
    println("找不到 Markdown 文件：\{missing}")
    js_set_exit_code(2)
    return
  }
  if !js_exists(bib_file) {
    println("找不到 BibTeX 文件：\{bib_file}")
    js_set_exit_code(2)
    return
  }
  let docs : Array[(String, String)] = []
  for f in md_files {
    docs.push((@moonbibguard.slash_path(f), js_read(f)))
  }
  let bib_text = js_read(bib_file)
  let bib_name = @moonbibguard.slash_path(bib_file)
  let report = @moonbibguard.analyze_docs(docs, bib_text, bib_file=bib_name)
  let text = if quiet {
    "检查完成：\{report.error_count} 个错误 · \{report.warning_count} 个警告"
  } else if format == "json" {
    @moonbibguard.to_json(report)
  } else if format == "github" {
    @moonbibguard.to_github(report)
  } else {
    @moonbibguard.format_report(
      report,
      markdown_file=join_files(md_files),
      bib_file=bib_name,
    )
  }
  if output != "" {
    if js_write(output, text) {
      println("报告已写入 \{output}")
    } else {
      println("无法写入 \{output}")
      js_set_exit_code(2)
      return
    }
  } else {
    js_print(text)
  }
  if report.error_count > 0 || (strict && report.warning_count > 0) {
    js_set_exit_code(1)
  } else {
    js_set_exit_code(0)
  }
}
