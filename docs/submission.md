# 提交导读（MoonBit 黑客松 2026 · 十一月赛）

这份文档把作品与赛事的验收标准逐条对上，方便评审快速核对，也方便自己提交前复查。

## 1. 作品信息

| 项 | 内容 |
| --- | --- |
| 作品名 | MoonBibGuard |
| 一句话定位 | 基于 MoonBit 的离线 Markdown + BibTeX 引用一致性检查库与 CLI |
| 仓库 | https://github.com/cookies060809/MoonBibGuard |
| Mooncakes | https://mooncakes.io/docs/cookies060809/moonbibguard（`0.1.0` → `0.1.1`） |
| 许可 | MIT |
| 语言 / 后端 | MoonBit（分析层 100% MoonBit）+ JS 后端；Node.js 仅做 argv 与文件 IO |
| 版本 | `0.1.1`（2026-11-26 发布） |

## 2. 对照六条验收标准

| 标准 | 本项目证据 |
| --- | --- |
| MoonBit 为主 | 解析、提取、规则、报告全部在 `.mbt` 中实现；外部依赖只有 `moonbitlang/core`；CLI 的 JS 只暴露 5 个 FFI（argv / exists / read / write / exitCode） |
| 仓库公开 | GitHub 公共仓库，MIT 许可，`main` 分支含完整历史与 CI 配置 |
| 能够运行 | `moon build --target js` 后一条 `node` 命令即可跑；`scripts/demo.ps1` / `demo.sh` 一键跑完六组场景 |
| 工作有效 | 四组样例 + 一组多文件样例的退出码与诊断条数可复现（见第 4 节），CI 每次提交都断言 |
| 开源合规 | MIT；`@string` 宏展开、Markdown 提取、诊断模型均为原创实现，未复制第三方代码 |
| AI 可解释 | `docs/architecture.md` 记录分层、状态机、规则复杂度、FFI 边界与取舍；`CHANGELOG.md` 记录每次变更与缺陷修复 |

## 3. 评审四维的自评与对应证据

> 以下是作者自评，结论均可按括注路径复核。

**工程深度与实现强度**

- BibTeX 用字符级状态机而非逗号切分：嵌套花括号、引号值、裸值、跨行字段、`%` 注释、`@comment/@preamble`、`@string` 与 `#` 拼接都能处理；单条坏条目通过 `recover_to_next_entry` 恢复，不会吞掉后续条目（`bibtex.mbt`、`docs/architecture.md` 第 4 节）。
- 定位精确到列：`Citation` 带 1-based 行号与键起始列号，诊断直接映射（`citation.mbt`）。
- 五类规则各有最小触发样例，`examples/broken/` 一次触发全部规则（4 错误 · 8 警告）。

**技术贡献与攻关**

- 攻关点一：MoonBit 的 FFI 与发布链路。`extern "js"` 在默认 wasm 后端不可用，`moon publish` 预检会直接失败；通过 `moon.mod` 的 `preferred_target = "js"` 与 `cmd/main/moon.pkg` 的 `supported_targets = "js"` 解决，并把 `#borrow` 的写法坑记进架构文档。
- 攻关点二：`#` 拼接的空格语义。按字面量解析会把 `{NeurIPS} # { 2023}` 拼成 `NeurIPS2023`；改为「值内部保留首尾空格、整值最后裁剪」才符合 BibTeX 直觉，这个是测试先抓出来的（`CHANGELOG.md` 0.1.1「修复」）。
- 攻关点三：`@string` 未闭合被循环条件静默吞掉，改用显式 `closed` 标志后补报 `MBG005`。

**生态增量**

- Mooncakes 上此前没有「BibTeX + Markdown 引用一致性」这类库；`moon add cookies060809/moonbibguard` 后，任何 MoonBit 文档工具都能直接调用 `analyze` / `analyze_docs`，无需自己实现 BibTeX 解析器。
- 已在独立工程 `%TEMP%\mbg-consumer`（`probe/consumer`）里真实安装 `0.1.1` 并调用 `analyze_docs` + `to_github` 通过测试，证明「发布物可被消费」，而不只是本地能跑。
- 输出层给出 JSON 与 GitHub Actions 注解两种机器接口，天然能进别人的 CI。

**开发与验证能力**

- 72 项测试全部通过，`moon check --target js --deny-warn` 零警告，`moon fmt` 幂等（CI 用 `git diff --exit-code` 校验）。
- CI（GitHub Actions，`ubuntu-latest`）覆盖：类型检查、单元测试、构建、四组端到端退出码断言、JSON 与 `examples/expected.json` 基准比对、`--format github` 注解前缀、`--strict` 语义。
- 提交历史按功能切分：`v0.1.0` 核心库与 CLI → 后端修复 → `v0.1.1` P1 功能与文档。

## 4. 复现清单（全部实测）

```bash
moon check --target js --deny-warn     # 零警告
moon test  --target js                 # Total tests: 72, passed: 72, failed: 0
moon build --target js
```

| 场景 | 命令（`js=_build/js/debug/build/cmd/main/main.js`） | 实测结果 |
| --- | --- | --- |
| 单文档 | `node $js examples/paper.md examples/references.bib` | 1 错误 · 1 警告，退出码 1 |
| 全部正确 | `node $js examples/clean/paper.md --bib examples/clean/references.bib` | 0/0，退出码 0 |
| 边界写法 | `node $js examples/boundary/paper.md --bib examples/boundary/references.bib` | 0/0，退出码 0 |
| 五类规则 | `node $js examples/broken/paper.md --bib examples/broken/references.bib` | 4 错误 · 8 警告，退出码 1 |
| 多文件 + `@string` | `node $js examples/book/ch1-intro.md examples/book/ch2-method.md --bib examples/book/references.bib` | 1 错误 · 1 警告，退出码 1 |
| CI 注解 | 上一条加 `--format github` | `::error file=examples/book/ch2-method.md,line=5,col=17::MBG001 …` |
| 严格门禁 | `node $js examples/clean/paper.md --bib examples/clean/references.bib --strict` | 0 警告下仍退出 0；有警告则退出 1 |

`scripts/demo.ps1`（Windows）与 `scripts/demo.sh`（Linux/macOS）把上述六组场景串成一次执行并断言退出码。

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
- [x] 可复现演示（四组样例 + 多文件样例 + 一键脚本）
- [x] 测试与 CI 结果（72 项 / 零警告 / Actions 全绿）
- [x] Mooncakes 发布页（`0.1.0`、`0.1.1`）
- [x] 架构与变更文档（`docs/architecture.md`、`CHANGELOG.md`）
- [ ] 赛事群昵称改为 GitHub ID（`cookies060809`）—— 由作者本人在群里完成
- [ ] 按官方通知填写报名 / 验收表单 —— 由作者本人提交

## 6. 已知不足

- 只支持 Pandoc 风格 `[@key]`，不解析 LaTeX `\cite{}`。
- 一次运行共享一个文献库，多库场景需多次调用后自行合并 JSON。
- 只在 JS 后端做过端到端验证；wasm / native 后端需要替换 FFI 层。
- 尚未做编辑器集成（LSP）与自动修复，仅报告不改文件。
