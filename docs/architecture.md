# MoonBibGuard 架构说明

这份文档写给想读懂或改造代码的人：先讲整体分层与数据流，再逐模块讲实现细节与设计取舍，最后是测试策略和扩展点。

## 1. 目标与边界

MoonBibGuard 要回答一个很窄的问题：**我 Markdown 正文里引用的键，和文献库里的键，对得上吗？** 对不上的地方在哪一行哪一列？

明确不做的事：

- 不判断文献本身是否真实存在（不联网、不查数据库）
- 不解析 PDF / Word
- 不自动改写源文件（只报告，不动手）
- 不做通用 Markdown 解析（只提取引用）

这条边界让整个项目可以保持零运行时依赖、纯离线、可嵌入。

## 2. 分层与数据流

```
                ┌──────────────────────────────┐
   .md 文件 ──▶ │ citation.mbt  extract_citations │ ──▶ Array[Citation]
                └──────────────────────────────┘
                ┌──────────────────────────────┐
   .bib 文件 ──▶│ bibtex.mbt   parse_bibtex      │ ──▶ BibDatabase{entries, errors, macros}
                └──────────────────────────────┘
                            │
                            ▼
                ┌──────────────────────────────┐
                │ analyzer.mbt analyze_docs      │ ──▶ Report{diagnostics, 计数}
                └──────────────────────────────┘
                            │
              ┌─────────────┼──────────────┐
              ▼             ▼              ▼
     format_report    to_json        to_github
        （终端）       （机器）        （CI 注解）
```

四个 `*_test.mbt` 是黑盒测试，通过 `@moonbibguard.xxx` 从外部调用公开 API，不触碰内部函数——这样测试约束的是「对外承诺的行为」，重构内部实现不会被测试绑死。

`cmd/main/main.mbt` 是唯一有副作用的地方：读 argv、读文件、写文件、设置退出码。它调用库的公开 API，自己不实现任何分析逻辑。所有 `extern "js"` 只出现在这个文件里。

## 3. 模块职责

| 文件 | 职责 | 不变量 |
| --- | --- | --- |
| `bibtex.mbt` | 把 BibTeX 文本变成条目、宏表、语法错误 | 任何输入都不 panic；坏条目不会吞掉后续条目 |
| `citation.mbt` | 把 Markdown 文本变成带位置的引用列表 | 代码块 / 行内代码内的 `[@...]` 一律不算 |
| `analyzer.mbt` | 对照引用与条目，产出诊断 | 一条诊断只对应一个可解释的事实；规则集合封闭（MBG001–005） |
| `diagnostic.mbt` | 诊断 → 文本 / JSON / GitHub 注解 | 同一 Report 的 JSON 输出稳定、字段顺序固定 |
| `cmd/main/main.mbt` | 参数解析、文件 IO、退出码 | 除它以外，库代码不接触文件系统 |

## 4. BibTeX 解析器

### 4.1 为什么是字符级状态机

按 `,` 和 `}` 切分的朴素做法会在这些地方翻车：

- `title = {Attention, Is All You Need}` —— 值里有逗号
- `author = {Knuth, Donald}` —— 同上
- `title = {{BERT}: Pre-training...}` —— 嵌套花括号
- `note = "a {nested} quote"` —— 引号值里带括号

所以解析器逐字符推进，维护 `depth`（花括号深度）与 `in_quote`（是否在引号值内）两个隐式状态，只有在 `depth == 0` 且不在引号内时，`,` 才是字段分隔符。

### 4.2 主循环

`parse_bibtex` 扫描 `@`：

1. 读到 `@` 后解析条目类型（纯字母，转小写）。
2. `@comment` / `@preamble`：跳过配对的花括号块，不产生条目。
3. `@string`：交给 `parse_string_def` 写入宏表，并支持一次定义多个 `name = value, name2 = value2`。
4. 其他类型：解析引用键，遇到 `,` 后进入 `parse_entry_body`。
5. 任何一步失败，`recover_to_next_entry` 跳到下一个 `@`，继续解析后面的条目。

### 4.3 值表达式与 `@string`

`parse_value` 是唯一的值入口，形态是：

```
value := term ('#' term)*
term  := '{' literal '}' | '"' literal '"' | bare-token
```

- `bare-token` 先查宏表（键名小写），命中就展开，未命中就按原文保留。保留原文是有意的：`month = jan` 这类 BibTeX 内建宏我们不去模拟，宁可原样呈现，也不编造一个值。
- `#` 拼接按顺序把各段文本拼起来。为了让 `{NeurIPS} # { 2023}` 得到 `NeurIPS 2023` 而不是 `NeurIPS2023`，`parse_braced` / `parse_quoted` **保留字面量首尾的空格**（内部连续空白仍折叠为一个空格），最后在 `parse_value` 返回前对**整值**做一次首尾裁剪。这是 v0.1.1 修掉的一个真实缺陷。
- `@string{broken = {Val}` 这种缺闭合的情况，循环会在 `i >= n` 时退出，若没有 `closed` 标志就静默通过；现在用显式 `closed` 在循环外补一条错误。

### 4.4 行号

行号在三种上下文里同步推进：`skip_space`（跨行空白）、`parse_braced` / `parse_quoted`（值内换行）、条目体循环。诊断因此能指到「字段所在的那一行」，而不是笼统的条目起始行。

## 5. Markdown 引用提取

### 5.1 先切行再扫字符

`extract_citations` 按 `\n` 切行，逐行扫描。行号天然 1-based，列号由字符下标 +1 得到。

### 5.2 三层排除

1. **围栏代码块**：遇到 ``` 或 ~~~ 开头的行就进入「代码块内」状态，直到同类围栏再次出现；未闭合围栏一直持续到文件末尾（这类文档本身已损坏，宁可少报也不误报）。
2. **行内代码**：反引号跨度内的字符直接跳过，`` `[@not_real]` `` 不算引用。
3. **方括号约束**：只认 `[...]` 内部的 `@key`，所以 `foo@bar.com`、`arr[@index]`、`[链接](https://x)` 都不会被当成引用。

### 5.3 支持的语法形态

| 写法 | 抽取结果 |
| --- | --- |
| `[@key]` | 1 条 |
| `[@a; @b]` | 2 条，位置各自独立 |
| `[-@key]` | 1 条（Pandoc 的「作者在场」写法） |
| `[@key, p. 33]` | 1 条，键在 `@` 之后、`;`/`,`/`]` 之前截止 |
| `[--@key]` | 1 条（多重破折号前缀） |

## 6. 规则引擎

`analyze_docs(docs, bibtex_text, bib_file~)` 是统一入口，`analyze(...)` 只是单文档的薄包装。执行顺序与复杂度：

| 规则 | 判定 | 复杂度 |
| --- | --- | --- |
| MBG005 | `BibDatabase.errors` 逐条转诊断 | O(错误数) |
| MBG002 | 用 `Map[key] → 首次行号` 扫一遍条目 | O(条目数) |
| MBG004 | 每个条目按 `required_fields(type)` 查字段是否存在 | O(条目数 × 字段数) |
| MBG001 | 每个引用查 `Map[key] → 条目`；未命中时对全库算编辑距离找最相近的键 | O(引用数 × 条目数)，仅在未命中时触发 |
| MBG003 | 引用集合的补集 | O(条目数) |

### 6.1 建议的噪声控制

「是否想引用 X？」只在**编辑距离 1–2 且键长 ≥ 4** 时给出。太短的键（如 `a1`、`k`）随便两个字符串距离都是 1–2，给了等于噪声；距离 ≥ 3 的猜测命中率太低，不如不说。`examples/broken/` 里 `vaswani2107` 能稳定给出 `是否想引用 vaswani2017？编辑距离 2`。

这个策略有个可预期副作用：笔误键既产生 MBG001（未定义），也会让被误拼的正确条目产生 MBG003（未使用）。两条诊断都成立，只是读起来略啰嗦；`examples/book/` 演示里让同一篇文献同时被正确引用，就不会出现这种双重提示。

### 6.2 多文档判定

`docs` 是 `(文件名, 正文)` 数组。每个引用带上自己的文件名一起进入诊断，因此 MBG001 能指到「第二章那一行」，而不是笼统说「某处引错了」。未使用条目判定用的是**所有文档引用键的并集**——只在第二章引用的文献不会被误报。

## 7. 报告模型与输出

`Report` 只存诊断与计数（错误 / 警告 / 提示 / 引用数 / 条目数），派生展示形式由 `diagnostic.mbt` 负责：

- `label()`：中文级别标签（错误 / 警告 / 提示）
- `tag()`：JSON 用的英文级别（error / warning / info）
- `format_report`：终端文本，带分隔线、建议行、统计行
- `to_json`：手写 JSON，字段顺序固定、字符串转义由 `json_escape` 负责，便于做快照回归（`examples/expected.json`）
- `to_github`：`::error file=...,line=...,col=...::MBG001 消息（建议：...）`，末尾追加一条 `::notice::` 汇总

`slash_path` 在 CLI 与 `to_github` 两处把 `\` 归一为 `/`：GitHub Actions 的注解要求仓库相对路径用正斜杠，而 JSON 报告归一后 Windows / Linux 的快照才能一致。

## 8. FFI 边界

CLI 只需要五个 Node 能力：`process.argv`、`existsSync`、`readFileSync`、`writeFileSync`、`process.exitCode`。全部集中在 `main.mbt` 的 `extern "js"` 声明里，并用 `#borrow(...)` 标注借用参数（多个参数要写在**同一条** `#borrow(a, b)` 里，分成两行会报 `borrow is duplicated`）。

发布时有个坑：`moon publish` 会先跑默认后端的 `moon check`，而 `extern "js"` 在 wasm 后端不可用，直接 11 个错误。解决办法是两处声明优先目标：

- `moon.mod`：`preferred_target = "js"`
- `cmd/main/moon.pkg`：`supported_targets = "js"`

## 9. 测试策略

| 层次 | 手段 |
| --- | --- |
| 单元 / 契约 | `moon test --target js`：72 项，覆盖解析、提取、规则、输出四类，全部通过公开 API 调用 |
| 编译健康 | `moon check --target js --deny-warn`：零警告是硬门槛 |
| 格式一致 | `moon fmt` 后 `git diff --exit-code`，防止格式化漂移 |
| 端到端 | CI 跑四组样例并断言退出码：clean / boundary 期望 0，broken / book 期望 1 |
| 报告稳定 | CI 用 `--json` 输出与 `examples/expected.json` 逐字段比对 |
| 新模式 | CI 额外验证 `--format github` 的注解前缀与 `--strict` 把警告升级为失败 |

测试样例的设计原则是「每加一条规则，就要有一个能让它触发的最小样例」，以及「每修一个 bug，先补一个会失败的测试」——v0.1.1 的 `#` 拼接空格 bug 和 `@string` 静默通过 bug 都是这样被测试先抓出来的。

## 10. 已知取舍

- **不做 `.bib` 的完整语法**（如 `@string` 内再定义、跨文件宏继承）：真实场景罕见，成本高于收益。
- **一次只对一个文献库做检查**：多库场景用多次运行 + 合并 JSON 解决。
- **不自动修复**：诊断给建议，改动交给人和编辑器；自动改写源文件的信任成本太高。
- **只在 JS 后体验证**：MoonBit 的 JS 后端是唯一端到端跑通的路径，其他后端需要替换 FFI 层。

## 11. 扩展点

- 新规则：在 `analyzer.mbt` 增加 `MBG00x` 分支，并在 `required_fields` / 引用集合等处复用现有索引；记得同步 README 规则表与 `docs` 的复杂度表。
- 新输出格式：在 `diagnostic.mbt` 加一个 `to_xxx(report)`，CLI 只需在 `--format` 分支里加一项。
- 新语言 / 新标记：`citation.mbt` 的扫描器与 `bibtex.mbt` 的状态机互不依赖，可以在不改解析器的前提下支持 `\cite{}` 或 Org-mode 的 `cite:` 链接。
