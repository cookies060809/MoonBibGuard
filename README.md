# MoonBibGuard

**基于 MoonBit 的离线 Markdown + BibTeX 引用一致性检查库与命令行工具。**

MoonBibGuard 只做一件事：检查你在 Markdown 里写的引用，和你的 `.bib` 文献库是否对得上，并把问题定位到**文件、行、列**。不联网、不依赖 GPU、不调用大模型。

[![CI](https://github.com/cookies060809/MoonBibGuard/actions/workflows/ci.yml/badge.svg)](https://github.com/cookies060809/MoonBibGuard/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/mooncakes-0.1.1-6a5acd)](https://mooncakes.io/docs/cookies060809/moonbibguard)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## 它解决什么问题

用 Markdown 写论文、研究笔记或技术报告时，常见错误是：

1. 正文写了 `[@vaswani2107]`，文献库里只有 `vaswani2017` —— 编译时要么静默失败，要么生成一个空引用。
2. `.bib` 里同一条文献被两个条目重复定义，导出时结果不确定。
3. 正文改动后留下没人引用的文献条目，参考文献表里多出无关条目。
4. `@article` 缺了 `journal`、`@inproceedings` 缺了 `booktitle`，导出条目信息不完整。
5. `.bib` 本身语法坏了（花括号没闭合），但工具直接崩掉或默默忽略。

MoonBibGuard 把这五类问题变成带编号、带位置的诊断。

## 快速开始

前置要求：

- [MoonBit 工具链](https://www.moonbitlang.com/download)：`moon version` 可执行（本项目实测 `moon 0.1.20261119`）
- Node.js 18 或更新（本项目实测 Node.js 22，仅用于运行 JS 后端的 CLI）

```bash
git clone https://github.com/cookies060809/MoonBibGuard.git
cd MoonBibGuard

moon check --target js      # 类型检查
moon test  --target js      # 运行全部单元测试
moon run --target js cmd/main -- examples/paper.md examples/references.bib
```

最后一条命令的真实输出：

```
MoonBibGuard 引用一致性检查
  正文：examples/paper.md
  文献库：examples/references.bib
--------------------------------
[错误] MBG001 examples/paper.md:5:12  未定义引用 attention2025：文献库中不存在该引用键
[警告] MBG003 examples/references.bib:15  未使用文献 unused2024：正文中没有引用它
         建议：删除该条目，或在正文中补上引用
--------------------------------
检查完成：1 个错误 · 1 个警告 · 0 条提示
统计：4 条正文引用 · 3 条 BibTeX 文献
```

`examples/paper.md` 里 `[@not_a_real_citation]` 和 `[@also_not_real]` 写在代码块与行内代码里，没有被误报 —— 这是本工具刻意处理的边界。

## 作为依赖安装（Mooncakes）

```bash
moon add cookies060809/moonbibguard
```

在 `moon.pkg` 里声明导入：

```
import {
  "cookies060809/moonbibguard",
}
```

之后即可在代码里用 `@moonbibguard.analyze(...)`。

## 诊断规则

| 代码 | 级别 | 含义 |
| --- | --- | --- |
| `MBG001` | 错误 | 正文引用的键在文献库中不存在；有相近键时给出编辑距离建议 |
| `MBG002` | 错误 | 同一引用键被多个 BibTeX 条目重复定义 |
| `MBG003` | 警告 | 文献库里有条目，正文从未引用 |
| `MBG004` | 警告 | 按条目类型缺少必需字段（`@article` 需 `author/title/year/journal` 等） |
| `MBG005` | 错误 | BibTeX 语法错误：值未闭合、字段缺 `=`、条目缺 `{,` 等 |

## 命令行用法

```bash
node _build/js/debug/build/cmd/main/main.js <paper.md> [<ch2.md> ...] --bib <references.bib> [选项]
```

| 选项 | 作用 |
| --- | --- |
| `--bib <文件>` | 显式指定文献库；可一次检查多个 Markdown |
| `--json` | 输出机器可读 JSON 报告 |
| `--format <格式>` | `text`（默认）、`json`、`github` |
| `-o, --output <文件>` | 把报告写入文件（UTF-8，无 BOM） |
| `--strict` | 警告也视为失败（退出码 1） |
| `--quiet` | 只输出一行统计 |
| `-h, --help` | 帮助 |
| `-v, --version` | 版本 |

不带 `--bib` 时按位置参数区分：`mbg a.md b.bib` 是单文档模式，`mbg a.md b.md --bib lib.bib` 是批量模式。

退出码：`0` 无错误级诊断，`1` 存在错误级诊断（或 `--strict` 下有警告），`2` 参数或文件问题（可直接用于 CI 门禁）。

JSON 报告结构（示例见 `examples/expected.json`，可用 `JSON.parse` 直接消费）：

```json
{
  "tool": "moonbibguard",
  "summary": { "errors": 1, "warnings": 1, "infos": 0, "diagnostics": 2, "citations": 4, "entries": 3 },
  "diagnostics": [
    { "code": "MBG001", "severity": "error", "file": "examples/paper.md", "line": 5, "column": 12,
      "message": "未定义引用 attention2025：文献库中不存在该引用键" }
  ]
}
```

`--format github` 直接输出 GitHub Actions 的 workflow command，PR 的「Files changed」里会出现逐行注解，路径中的 `\` 会自动转成 `/`：

```
::error file=examples/paper.md,line=5,col=12::MBG001 未定义引用 attention2025：文献库中不存在该引用键
::warning file=examples/references.bib,line=15::MBG003 未使用文献 unused2024：正文中没有引用它（建议：删除该条目，或在正文中补上引用）
::notice::MoonBibGuard 完成：1 个错误 · 1 个警告 · 4 条引用
```

## 作为 MoonBit 库使用

核心分析全部由 MoonBit 实现，CLI 只是它的一层壳。其他 MoonBit 项目可以直接复用：

```moonbit
let report = @moonbibguard.analyze(markdown_text, bibtex_text)
let text = @moonbibguard.format_report(report)     // 终端文本
let json = @moonbibguard.to_json(report)           // JSON 字符串
```

公开 API：

| API | 说明 |
| --- | --- |
| `parse_bibtex(text) -> BibDatabase` | 解析 BibTeX，返回条目、语法错误与 `@string` 宏表 |
| `extract_citations(text) -> Array[Citation]` | 提取 Markdown 中的 `[@key]`、`[@a; @b]`、`[-@key]`，带行号列号 |
| `analyze(md, bib, markdown_file~, bib_file~) -> Report` | 单文档完成五类检查 |
| `analyze_docs(docs, bib, bib_file~) -> Report` | 多文档合并检查：`docs` 是 `(文件名, 正文)` 数组，未使用条目按全部文档的引用集合判定 |
| `format_report(report, ...) -> String` | 生成终端可读报告 |
| `to_json(report) -> String` | 生成稳定 JSON 报告 |
| `to_github(report) -> String` | 生成 GitHub Actions 注解 |
| `slash_path(path) -> String` | 统一路径分隔符，去掉前导 `./` |
| `levenshtein(a, b) -> Int` | 编辑距离，用于“是否想引用 …”建议 |
| `required_fields(entry_type) -> Array[String]` | 各条目类型的必需字段表 |

## 演示数据（四组，均可复现）

| 目录 | 场景 | 实测结果 |
| --- | --- | --- |
| `examples/` | 方案演示：1 处未定义引用 + 1 条未使用文献 | 1 错误 · 1 警告，退出码 1 |
| `examples/clean/` | 全部正确，含代码块与邮箱地址干扰 | 0 错误 · 0 警告，退出码 0 |
| `examples/broken/` | 五种规则一起触发：未定义、重复键、缺字段、未使用、语法错误 | 4 错误 · 8 警告，退出码 1 |
| `examples/boundary/` | 嵌套花括号、引号字段、裸年份、`[@k, p. 42]` 定位、行内代码 | 0 错误 · 0 警告，退出码 0 |
| `examples/book/` | 两章 Markdown + 一个含 `@string` 宏的文献库：跨文件引用合并判定、笔误建议、真正未使用的条目 | 1 错误 · 1 警告，退出码 1 |

```bash
moon run --target js cmd/main -- examples/clean/paper.md examples/clean/references.bib
moon run --target js cmd/main -- examples/broken/paper.md examples/broken/references.bib
moon run --target js cmd/main -- examples/boundary/paper.md examples/boundary/references.bib
moon run --target js cmd/main -- examples/book/ch1-intro.md examples/book/ch2-method.md --bib examples/book/references.bib
```

## 实现要点

- **BibTeX 用字符级状态机解析**，不是按逗号切分：正确处理嵌套花括号、引号包裹值、裸值（`year = 2023`）、跨行字段、`%` 注释、`@comment/@preamble` 跳过，并在报错后恢复到下一条 `@`，一条坏条目不会吞掉整个文献库。
- **`@string` 宏与 `#` 拼接按 BibTeX 语义展开**：`@string{acm = {ACM Press}}` 定义后，`publisher = acm`、`booktitle = conf # { 2023}` 都会展开成实际文本；宏名大小写不敏感，未定义的裸词按原文保留。拼接时保留字面量首尾的空格，最后才对整个值做首尾裁剪，因此 `{NeurIPS} # { 2023}` 不会粘成 `NeurIPS2023`。
- **Markdown 提取先切行再扫字符**：围栏代码块（``` / ~~~）内部整体跳过，行内反引号跨度跳过，只有 `[...]` 内部的 `@key` 才算引用，因此邮箱、数组中括号、普通链接都不会误报。
- **多文档合并判定**：每个引用带上来源文件名，未使用条目按所有文档的引用并集判断，跨章引用不会被误报为“未使用”。
- **位置精确到列**：每个 `Citation` 记录 1-based 行号与键起始列号，诊断直接映射过去。
- **拼写建议**：对所有文献键算 Levenshtein 距离，距离 1–2 且键长 ≥ 4 时才提示，避免噪声。
- **零依赖**：只用 `moonbitlang/core`，Node 仅承担 `argv` 与文件读写。

## 测试与 CI

```bash
moon test --target js          # 72 项，全部通过
moon check --target js --deny-warn   # 零警告
```

测试分布：

| 类别 | 覆盖内容 |
| --- | --- |
| BibTeX 解析（27 项） | 空库、单条、多行值、嵌套花括号、引号、裸值、括号式条目、重复键、未闭合、缺 `=`、缺 `{`、注释行、行号、中文标题、空白折叠、`@string` 展开、`#` 拼接、宏大小写、宏表导出、`@string` 未闭合 |
| Markdown 提取（15 项） | 单引用、多引用、负号引用、定位信息、列号、行号、围栏代码块、行内代码、普通链接、邮箱、未闭合围栏、特殊字符键 |
| 一致性分析（18 项） | 干净文档、未定义引用、重复键、未使用文献、缺字段、语法错误、拼写建议、统计、代码块不计数、编辑距离、跨文档引用合并、出错文件归属、空文档列表 |
| 报告输出（12 项） | 严重级别标签、空报告文案、文本报告位置、建议行、JSON 摘要、引号转义、可选字段、GitHub 注解格式、路径分隔符归一 |

CI 配置在 `.github/workflows/ci.yml`，使用 `hustcer/setup-moonbit` 安装工具链，依次跑 `moon check --deny-warn`、`moon test`、`moon build`，并分别用干净样例（期望成功）和错误样例（期望退出码 1）做端到端校验，最后检查 `moon fmt` 是否幂等。

## 与已有工具的区别

| 项目 | 侧重 | 与本项目的关系 |
| --- | --- | --- |
| BibGuard | 文献真实性核验、报告生成 | 侧重不同：本项目不判断文献真假，只判断引用是否对得上 |
| bib-check / citecheck | 联网比对学术数据库 | 本项目完全离线，无网络依赖 |
| mizchi/markdown、kokic/cmark | MoonBit 通用 Markdown 解析 | 本项目不做通用 Markdown，只做引用提取这一件事 |

MoonBibGuard 的定位是**离线、可定位、可嵌入**：既能当 CLI 用，也能作为 MoonBit 库被别的程序调用。

## 已知限制

- 只检查 Pandoc 风格的方括号引用 `[@key]`、`[@a; @b]`、`[-@key]`；不支持 LaTeX 的 `\cite{}`，也不把正文里裸写的 `@key` 当引用。
- 不做 PDF/Word 解析，不联网核验文献真伪，不自动改写源文件。
- `@string` 支持 `@string{...}` 定义与 `#` 拼接，但不支持 `@string` 内再定义、跨文件宏表继承。
- 只能在一次运行内共享一个文献库；同一目录下多个独立 `.bib` 需要分多次调用（或用 `-o` 合并 JSON）。
- 主要在 Windows + JS 后端验证；CI 在 Ubuntu 上跑同一套测试，其他平台理论可用但未单独验证。

## 路线

`v0.1.0` 完成 P0：五类规则、精确位置、CLI + JSON、57 项测试、四组演示、CI、Mooncakes 发布。

`v0.1.1` 完成 P1：`@string` 宏与 `#` 拼接、多 Markdown 批量检查（`--bib` / `analyze_docs`）、`--format github` 注解、`--strict` 门禁、72 项测试、跨平台路径归一。

后续候选（未承诺）：引用键重复引用同一文献的合并提示、Pandoc `--citeproc` 对照校验、编辑器 LSP 集成、`.bib` 排序与格式化建议。

## 许可

MIT，见 [LICENSE](LICENSE)。
