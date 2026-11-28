# 提交导读（MoonBit 黑客松 2026 · 十一月赛）

这份文档把作品与赛事的验收标准逐条对上，方便评审快速核对，也方便自己提交前复查。

## 1. 作品信息

| 项 | 内容 |
| --- | --- |
| 作品名 | MoonBibGuard |
| 一句话定位 | 基于 MoonBit 的离线 Markdown + BibTeX 引用一致性检查库与 CLI |
| 仓库 | https://github.com/cookies060809/MoonBibGuard |
| Mooncakes | https://mooncakes.io/docs/cookies060809/moonbibguard（`0.1.0` → `0.1.1` → `0.2.0`） |
| 许可 | MIT |
| 语言 / 后端 | MoonBit（分析层 100% MoonBit，含配置解析）+ JS 后端；Node.js 仅做 argv 与文件 IO |
| 版本 | `0.2.0` |

## 2. 对照六条验收标准

| 标准 | 本项目证据 |
| --- | --- |
| MoonBit 为主 | 解析、提取、规则、配置解析、文本/JSON/GitHub/SARIF 四种报告全部在 `.mbt` 中实现；外部依赖只有 `moonbitlang/core`（含 `core/json`）；CLI 的 JS 只暴露 5 个 FFI |
| 仓库公开 | GitHub 公共仓库，MIT 许可，`main` 分支含完整历史、CI 配置与版本 tag |
| 能够运行 | `moon build --target js` 后一条 `node` 命令即可跑；`scripts/demo.ps1` / `demo.sh` 一键跑完八组场景 |
| 工作有效 | 六组样例目录的退出码与诊断条数可复现，CI 每次提交都断言；JSON 输出与 `examples/expected.json` 基准逐字段比对 |
| 开源合规 | MIT；`@string` 展开、Markdown 提取、诊断模型、SARIF 生成、配置解析均为原创实现，未复制第三方代码 |
| AI 可解释 | `docs/architecture.md`（分层/状态机/复杂度/FFI）、`docs/rules.md`（错误码与配置语义）、`docs/compatibility.md`（与 Pandoc 的差异）、`docs/performance.md`（实测基准）、`CHANGELOG.md` |

## 3. 评审四维的自评与对应证据

> 以下是作者自评，结论均可按括注路径复核。

**工程深度与实现强度**

- BibTeX 字符级状态机：嵌套花括号、引号值、裸值、跨行字段、`%` 注释、`@string` 与 `#` 拼接；单条坏条目通过 `recover_to_next_entry` 恢复（`bibtex.mbt`）。
- 定位精确到列；`Citation` 带 1-based 行号与键起始列号（`citation.mbt`）。
- 四种报告格式共用同一份 `Report`：文本 / JSON / GitHub 注解 / SARIF 2.1.0（`diagnostic.mbt`、`sarif.mbt`）。
- 六组样例覆盖「干净 / 边界 / 五类规则齐发 / 多文件 / 仿真实论文 / 方案演示」，每组的退出码都被 CI 断言。

**技术贡献与攻关**

- 攻关一：MoonBit 发布链路。`extern "js"` 在默认 wasm 后端不可用会卡住 `moon publish` 预检，用 `preferred_target = "js"` + `supported_targets = "js"` 解决，`#borrow` 的写法坑记入架构文档。
- 攻关二：`#` 拼接的空格语义。字面量解析会把 `{NeurIPS} # { 2023}` 粘成 `NeurIPS2023`，改为「值内保留首尾空格、整值最后裁剪」才符合 BibTeX 直觉（`CHANGELOG` 0.1.1「修复」）。
- 攻关三：`@string` 未闭合被循环条件静默吞掉，改用显式 `closed` 标志补报 `MBG005`。
- 攻关四：配置的容错。坏 JSON、错误级别、非对象、UTF-8 BOM 一律降级为提示而不是中止；Windows 下 PowerShell 写出的 BOM 是实测踩到的坑。

**生态增量**

- Mooncakes 上此前没有「BibTeX + Markdown 引用一致性」这类库；`moon add cookies060809/moonbibguard` 后可直接调用 `analyze` / `analyze_docs` / `to_sarif` / `parse_config`。
- 已在独立工程 `%TEMP%\mbg-consumer`（`probe/consumer`）里真实安装 `0.1.1` 并调用 `analyze_docs` + `to_github` 通过测试，证明发布物可被消费。
- 输出层给出 JSON（有 schema）、GitHub 注解、SARIF 三种机器接口，能直接进别人的 CI 与代码扫描面板。

**开发与验证能力**

- 95 项测试全部通过，`moon check --target js --deny-warn` 零警告，`moon fmt` 幂等（CI 用 `git diff --exit-code` 校验）。
- CI 覆盖：类型检查、单元测试、构建、六组样例退出码、JSON 基准比对、GitHub 注解前缀、`--strict` 语义、SARIF/配置 schema 校验、一键演示脚本。
- `scripts/bench.mjs` 给出可复现的性能数据（1 万条文献 + 1 万条引用 167 ms）。
- 提交历史按功能切分，且每个版本都有 tag。

## 4. 复现清单（全部实测）

```bash
moon check --target js --deny-warn     # 零警告
moon test  --target js                 # Total tests: 95, passed: 95, failed: 0
moon build --target js
```

表内 `js=_build/js/debug/build/cmd/main/main.js`。

| 场景 | 命令 | 实测结果 |
| --- | --- | --- |
| 单文档 | `node $js examples/paper.md examples/references.bib` | 1 错误 · 1 警告，退出码 1 |
| 全部正确 | `node $js examples/clean/paper.md --bib examples/clean/references.bib` | 0/0，退出码 0 |
| 边界写法 | `node $js examples/boundary/paper.md --bib examples/boundary/references.bib` | 0/0，退出码 0 |
| 五类规则 | `node $js examples/broken/paper.md --bib examples/broken/references.bib` | 4 错误 · 8 警告，退出码 1 |
| 多文件 + `@string` | `node $js examples/book/ch1-intro.md examples/book/ch2-method.md --bib examples/book/references.bib` | 1 错误 · 1 警告，退出码 1 |
| 仿真实论文 + 配置 | `node $js examples/paper-project/intro.md examples/paper-project/method.md --config examples/paper-project/.moonbibguard.json` | 0/0，退出码 0 |
| CI 注解 | 任一场景加 `--format github` | `::error file=examples/book/ch2-method.md,line=5,col=17::MBG001 …` |
| SARIF | 任一场景加 `--format sarif` | 合法 SARIF 2.1.0，含 5 条规则与 `executionSuccessful` |
| 严格门禁 | `node $js examples/clean/paper.md --bib examples/clean/references.bib --strict` | 0 警告下仍退出 0；有警告则退出 1 |
| Schema 校验 | `node scripts/check-schema.mjs` | 报告 / SARIF / 配置全部符合 schema |
| 性能 | `node scripts/bench.mjs` | 100 → 10,000 条规模最小 49.1 → 167.4 ms |

多文件演示的真实输出（`examples/book`）：

```
MoonBibGuard 引用一致性检查
  正文：examples/book/ch1-intro.md, examples/book/ch2-method.md
  文献库：examples/book/references.bib
--------------------------------
[错误] MBG001 examples/book/ch2-method.md:5:17  未定义引用 vaswan2017：文献库中不存在该引用键
         建议：是否想引用 vaswani2017？编辑距离 1
[警告] MBG003 examples/book/references.bib:17  未使用文献 orphan2024：正文中没有引用它
         建议：删除该条目，或在正文中补上引用
--------------------------------
检查完成：1 个错误 · 1 个警告 · 0 条提示
统计：4 条正文引用 · 3 条 BibTeX 文献
```

## 5. 提交材料清单

- [x] 公开仓库链接与 MIT 许可
- [x] README（定位、快速开始、规则表、CLI、API、演示结果、限制、路线）
- [x] 可复现演示（六组样例 + 一键脚本 + 八组场景断言）
- [x] 测试与 CI 结果（95 项 / 零警告 / Actions 全绿）
- [x] Mooncakes 发布页（`0.1.0`、`0.1.1`、`0.2.0`）
- [x] 架构、规则、兼容性、性能四份文档 + `CHANGELOG.md`
- [x] JSON 报告与配置文件的 schema（`schema/`）
- [ ] 赛事群昵称改为 GitHub ID（`cookies060809`）—— 由作者本人在群里完成
- [ ] 按官方通知填写报名 / 验收表单 —— 由作者本人提交

## 6. 已知不足

- 只支持 Pandoc 风格 `[@key]`，不解析 LaTeX `\cite{}`，不识别正文裸写的 `@key`。
- 与 Pandoc 的对照是「按文档语义整理的一致性用例」，本机未安装 Pandoc，未做运行时差异对照（方法与命令见 `docs/compatibility.md`）。
- 配置文件暂不支持按路径忽略或 glob 排除目录。
- 一次运行共享一个文献库，多库场景需多次调用后自行合并。
- 只在 JS 后端做过端到端验证；wasm / native 后端需要替换 FFI 层。
