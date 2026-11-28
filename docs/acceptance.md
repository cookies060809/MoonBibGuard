# 验收材料（可直接粘贴）

这份文档是给「项目验收」那一步准备的：需要填表、发群消息或在飞书表格里补说明时，直接复制对应段落即可。所有数字都来自仓库实测，可复核。

## 一、项目一句话

> MoonBibGuard 是一个用 MoonBit 实现的离线 Markdown + BibTeX 引用一致性检查库与 CLI：把「正文引用键对不上文献库」这类问题提前到写作期，给出文件/行/列定位、相近键建议，并能以文本、JSON、GitHub 注解、SARIF 四种形式接入 CI。

## 二、本期新增工作（相对已有版本）

| 版本 | 内容 |
| --- | --- |
| `0.1.0` | 五类规则（未定义引用 / 重复键 / 未使用文献 / 缺必需字段 / BibTeX 语法错误）、精确行列定位、CLI + JSON、57 项测试、四组样例、CI、Mooncakes 首发 |
| `0.1.1` | `@string` 宏与 `#` 拼接、多 Markdown 批量检查（`analyze_docs` / `--bib`）、`--format github` 注解、`--strict`、72 项测试 |
| `0.2.0` | **SARIF 2.1.0 输出**、**`.moonbibguard.json` 配置（规则开关 / 级别改写，读写均容错）**、**JSON 与配置 schema + 零依赖校验器**、仿真实论文演示项目、性能基准、95 项测试、文档四件套（架构 / 规则 / 兼容性 / 性能） |

本期实质性新增（0.2.0 为主）：

1. SARIF 2.1.0 报告：`ruleId` 稳定代码、`level` 映射 `error/warning/note`、位置进 `physicalLocation`、路径统一 `/` URI、有错误时 `executionSuccessful=false`。
2. 配置文件：`rules`（off/error/warning/info）、`format`、`strict`、`bib`；当前目录自动读取，`--config` 指定；命令行 > 配置 > 默认；坏 JSON / 错级别 / 非对象 / UTF-8 BOM 一律降级为提示。
3. 契约化：`schema/report.schema.json`、`schema/config.schema.json` + `scripts/check-schema.mjs`（CI 每次校验真实输出）。
4. 引用解析边界：`[@smith2024, pp. 12-15]`、`[see @a, ch. 3]`、`[@a;@b]`、`[**@b**]`、嵌套方括号、`[-@a]` 全部固化进测试。
5. 工程验证：95 项测试、零警告、`moon fmt` 幂等、8 组一键演示、性能基准。

## 三、验证方式（复制即用）

```bash
git clone https://github.com/cookies060809/MoonBibGuard.git
cd MoonBibGuard

moon check --target js --deny-warn    # 期望：零警告
moon test  --target js                # 期望：Total tests: 95, passed: 95, failed: 0
moon build --target js

# 一键跑完 8 组场景并断言退出码（Windows / Linux 各一份脚本）
powershell -ExecutionPolicy Bypass -File scripts/demo.ps1   # Windows
bash scripts/demo.sh                                        # Linux / macOS
```

单条演示（错误案例，期望退出码 1）：

```bash
node _build/js/debug/build/cmd/main/main.js examples/paper.md examples/references.bib
```

期望输出：

```
MoonBibGuard 引用一致性检查
  正文：examples/paper.md
  文献库：examples/references.bib
--------------------------------
[错误] MBG001 examples/paper.md:5:12  未定义引用 attention2025：文献库中不存在该引用键
[警告] MBG003 examples/references.bib:15  未使用文献 unused2024：正文中没有引用它
--------------------------------
检查完成：1 个错误 · 1 个警告 · 0 条提示
```

机器可读与 CI 形态：

```bash
node _build/js/debug/build/cmd/main/main.js examples/paper.md examples/references.bib --json
node _build/js/debug/build/cmd/main/main.js examples/paper.md examples/references.bib --format sarif
node _build/js/debug/build/cmd/main/main.js examples/paper.md examples/references.bib --format github
node scripts/check-schema.mjs     # 期望：全部输出符合 schema
node scripts/bench.mjs            # 期望：100 → 10000 条规模 49.1 → 167.4 ms
```

## 四、可复现演示（8 组，全部被 CI 断言）

| 场景 | 期望 |
| --- | --- |
| `examples/` 单文档 | 1 错误 · 1 警告，退出码 1 |
| `examples/clean/` | 0 / 0，退出码 0 |
| `clean` + `--strict` | 0 / 0，退出码 0 |
| `examples/boundary/` | 0 / 0，退出码 0 |
| `examples/broken/` | 4 错误 · 8 警告，退出码 1 |
| `examples/book/` 两章 + `@string` | 1 错误 · 1 警告，退出码 1 |
| `examples/paper-project/` + 配置文件 | 0 / 0，退出码 0 |
| `examples/paper.md --format sarif` | 合法 SARIF，退出码 1 |

## 五、验收对照（六条标准）

| 标准 | 对应证据 |
| --- | --- |
| MoonBit 为主 | 解析 / 提取 / 规则 / 配置 / 四种报告均在 `.mbt`；外部依赖仅 `moonbitlang/core`；Node 只做 argv 与文件 IO |
| 仓库公开 | https://github.com/cookies060809/MoonBibGuard（MIT） |
| 能够运行 | README 快速开始 + `scripts/demo.ps1` / `demo.sh` 一键 8 组 |
| 工作有效 | 本期 0.1.0 → 0.2.0 的实质新增见第二节；CI 全绿（95 项测试） |
| 开源合规 | MIT；原创实现，未移植、未复制第三方代码 |
| AI 可解释 | `docs/architecture.md`、`docs/rules.md`、`docs/compatibility.md`、`docs/performance.md`、`CHANGELOG.md` |

## 六、开发历程与心得（提纲，可扩写成文章）

如果验收入口要求「开发历程」或「心得体会」，可以按这个骨架扩写（每节 150–300 字）：

1. **起点**：写作时正文引用与 `.bib` 经常对不上，编译失败或渲染成 `[?]`；现有工具要么联网、要么依赖重。目标定为「离线、能定位到行列、可被别的程序复用」。
2. **第一版取舍**：先不做 PDF/Word、不联网核验真伪、不自动改文件，只做五类规则的确定性检查；BibTeX 用字符级状态机而不是逗号切分。
3. **踩坑与攻关**：`extern "js"` 在默认 wasm 后端不可用导致 `moon publish` 预检失败（改用 `preferred_target`）；`#` 拼接把 `{NeurIPS} # { 2023}` 粘成 `NeurIPS2023`（改为值内保留首尾空格、整值末尾裁剪）；`@string` 未闭合被循环条件吞掉（改显式 `closed` 标志）。
4. **测试先行的收益**：上面两个缺陷都是先写测试再修的；测试从 57 → 72 → 95，每次扩功能都先补边界用例。
5. **AI 的使用方式**：用 AI 做脚手架、文档与重复性测试补齐；关键设计（状态机、规则语义、SARIF 映射、配置容错）逐条人工确认，并写进 `docs/` 让评审能复核。
6. **本期做得不够的地方**：没有与 Pandoc 做运行时差异对照（本机未装 Pandoc，只做了文档语义用例）；配置还不支持路径级忽略；未做编辑器 LSP。
7. **下一步**：路径级忽略、Pandoc 运行时对照、大规模文献库下的编辑距离剪枝。

## 七、可能被问到的字段

| 字段 | 填什么 |
| --- | --- |
| 仓库 | https://github.com/cookies060809/MoonBibGuard |
| 主分支最新提交 | 见仓库 `main` 最新 commit（每次提交说明都写明版本与内容） |
| 包地址 | https://mooncakes.io/docs/cookies060809/moonbibguard（`0.2.0`） |
| 许可证 | MIT |
| 技术栈 | MoonBit（JS 后端）+ Node.js（仅 IO） |
| 测试规模 | 95 项，`moon test --target js` |
| 演示命令 | `powershell -File scripts/demo.ps1` 或 `bash scripts/demo.sh` |
| 版本 tag | `v0.1.1`、`v0.2.0` |
