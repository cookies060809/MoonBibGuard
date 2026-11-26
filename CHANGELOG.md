# Changelog

本项目的所有重要变更记录在这里，格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循语义化版本。

## [0.1.1] - 2026-11-26

### 新增

- `@string` 宏定义解析（`@string{acm = {ACM Press}}`），宏名大小写不敏感，宏表通过 `BibDatabase.macros` 暴露。
- BibTeX 的 `#` 拼接值（`booktitle = conf # { 2023}`），支持「宏 + 字面量」「字面量 + 字面量」「引号 + 宏」等组合。
- 多 Markdown 批量检查：新增库函数 `analyze_docs(docs, bibtex_text, bib_file~)`，`docs` 为 `(文件名, 正文)` 数组；未使用条目按全部文档的引用并集判定。
- CLI 新增 `--bib <文件>`，用于显式指定文献库后再传多个 Markdown；不带该参数时仍兼容 `mbg a.md b.bib` 的旧写法。
- CLI 新增 `--format text|json|github`；`github` 输出 GitHub Actions workflow command，可在 PR 的 Files changed 里逐行注解。
- CLI 新增 `--strict`：警告也返回退出码 1，便于在 CI 中把「未使用文献」也当作门禁。
- 新增 `to_github(report)` 与 `slash_path(path)` 两个公开函数。
- 新增 `examples/book/` 演示：两章 Markdown + 含 `@string` 的文献库，覆盖跨文件引用合并、笔误建议与真正未使用的条目。

### 变更

- 诊断中的文件路径统一归一为 `/` 分隔并去掉前导 `./`，Windows 与 Linux 下 JSON 报告完全一致（`examples/expected.json` 可作为回归基准）。
- `parse_braced` / `parse_quoted` 不再裁剪字面量首尾空格，改为在 `parse_value` 结尾对整值裁剪；这是让 `#` 拼接不粘连的必要前提。
- `@string` 块未闭合时一定会报一条 `MBG005`，此前该错误可能被循环条件吞掉。

### 修复

- `@string{...}` 缺少闭合花括号时静默通过的问题。
- `{A} # { B}` 拼接结果变成 `AB` 的问题。
- JSON 报告中 Windows 反斜杠导致的跨平台快照不一致。

### 测试

- 测试数从 57 增至 72：新增 `@string` 展开、`#` 拼接（3 种组合）、宏大小写、未知裸词保留、`@string` 未闭合、多文档合并判定、出错文件归属、空文档列表、GitHub 注解格式、路径归一。

## [0.1.0] - 2026-11-26

### 新增

- BibTeX 字符级状态机解析器：嵌套花括号、引号值、裸值、跨行字段、`%` 注释、`@comment/@preamble` 跳过、错误后恢复到下一条 `@`。
- Markdown 引用提取：`[@key]`、`[@a; @b]`、`[-@key]`、`[@key, p. 33]`，跳过围栏代码块与行内代码，带 1-based 行号与键起始列号。
- 五条诊断规则：`MBG001` 未定义引用（带 Levenshtein 建议）、`MBG002` 重复键、`MBG003` 未使用文献、`MBG004` 缺必需字段、`MBG005` 语法错误。
- 报告输出：终端文本、稳定 JSON、`--json` / `-o` / `--quiet` 选项，退出码 `0/1/2`。
- CLI 使用 Node.js 仅做 `argv` 与文件读写，全部分析逻辑在 MoonBit 中完成。
- 四组演示数据（`examples/`、`clean/`、`broken/`、`boundary/`）与 `examples/expected.json` 回归基准。
- GitHub Actions CI：`moon check --deny-warn`、`moon test`、`moon build`、端到端退出码校验、`moon fmt` 幂等检查。
- 发布到 Mooncakes：`cookies060809/moonbibguard@0.1.0`。
