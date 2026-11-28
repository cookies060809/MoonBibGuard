# 诊断规则与配置说明

MoonBibGuard 的全部诊断都带稳定代码，代码是给程序和 CI 用的，消息是给人看的。代码不会因为文案调整而改变。

## 规则总表

| 代码 | 默认级别 | SARIF 名称 | 触发条件 | 能否关闭 |
| --- | --- | --- | --- | --- |
| `MBG001` | error | `undefined-citation` | 正文引用的键在文献库中不存在 | 可 |
| `MBG002` | error | `duplicate-key` | 同一引用键被多个条目定义 | 可 |
| `MBG003` | warning | `unused-entry` | 文献库里的条目在全部正文中都没被引用 | 可 |
| `MBG004` | warning | `missing-field` | 条目按其类型缺少必需字段 | 可 |
| `MBG005` | error | `bibtex-syntax` | BibTeX 语法错误：值未闭合、字段缺 `=`、条目缺 `{,`、`@string` 未闭合 | 可 |

默认级别的取舍：**能让参考文献表出错或让编译失败的记 error**（MBG001 / MBG002 / MBG005）；**会让输出不完整但不致命的记 warning**（MBG003 / MBG004）。所以默认退出码只把 error 当失败，warning 只是提醒。

## 逐条说明

### MBG001 未定义引用（error）

正文写了 `[@smith2024]`，但 `.bib` 里没有 `smith2024`。这是最常见、后果最直接的一类：Pandoc 导出时该引用会变成空文本或 `[?]`。

定位到 Markdown 的文件 / 行 / 列（列是键首字符的位置）。若文献库中存在编辑距离 1–2 且长度 ≥ 4 的键，会附一条建议：

```
[错误] MBG001 paper.md:5:12  未定义引用 attention2025：文献库中不存在该引用键
         建议：是否想引用 vaswani2017？编辑距离 2
```

**怎么修**：改正正文里的键，或在 `.bib` 里补上该条目。

### MBG002 重复引用键（error）

同一个键被定义两次（典型来源是复制粘贴条目后忘记改键）。BibTeX 遇到重复键的行为依实现而定，Pandoc 通常取最后一个，结果不可预期。

```
[错误] MBG002 references.bib:15  重复的引用键 dup2020，它已在第 8 行定义过
         建议：为其中一条文献改用唯一的引用键
```

**怎么修**：给其中一条换个唯一键；若两条其实是同一文献，删掉其中一条。

### MBG003 未使用文献（warning）

文献库里有条目，但所有被检查的 Markdown 都没引用它。常见于删改正文后遗留的条目。

多文件模式下判定依据是**全部文档引用键的并集**，只在第二章引用的文献不会被误报。

**怎么修**：删掉该条目，或在正文补上引用。如果某些条目是「预留待引用」的，可以在配置里关掉这条规则。

### MBG004 缺必需字段（warning）

不同条目类型有不同的必需字段：

| 类型 | 必需字段 |
| --- | --- |
| `@article` | author, title, year, journal |
| `@inproceedings` / `@conference` | author, title, year, booktitle |
| `@book` / `@booklet` | title, publisher, year |
| `@incollection` | author, title, booktitle, year |
| `@phdthesis` / `@mastersthesis` | author, title, school, year |
| `@techreport` | author, title, institution, year |
| `@misc` / `@online` / `@unpublished` | title |
| 其他 | title |

只检查字段存在与否，不检查内容质量（比如年份是不是数字）。

### MBG005 BibTeX 语法错误（error）

解析器在出问题的位置给出一条诊断，然后**跳过当前条目、从下一个 `@` 继续**，所以一条坏条目不会让整个文献库失败。覆盖的情形：值未闭合、字段缺 `=`、条目缺 `{` 或 `,`、`@string` 没有闭合花括号。

## 规则开关与级别改写

配置文件 `.moonbibguard.json`（放当前工作目录会自动读取，也可用 `--config` 指定别的路径）：

```json
{
  "rules": {
    "MBG003": "off",
    "MBG004": "warning",
    "MBG001": "error"
  },
  "format": "sarif",
  "strict": true,
  "bib": "references.bib"
}
```

- `rules`：键是规则代码，值是 `off` / `error` / `warning` / `info`。`off` 表示该规则不产生诊断；其他值表示改写级别（计数会同步重算，JSON / SARIF 里的 summary 一致）。
- `format`：默认输出格式，命令行 `--format` 优先。
- `strict`：等价于命令行 `--strict`，命令行优先。
- `bib`：默认文献库路径，命令行 `--bib` 优先。

优先级规则：**命令行 > 配置文件 > 内置默认**。

容错行为：JSON 写坏、顶层不是对象、级别拼错，都只打印一条「配置提示」并退回默认值，不会中止检查——配置文件里的一个错字不应该让 CI 变红。UTF-8 BOM 会被自动去掉（Windows 编辑器常加）。

## 退出码

| 退出码 | 含义 |
| --- | --- |
| `0` | 没有 error 级诊断（`--strict` 下也没有 warning） |
| `1` | 有 error 级诊断；或 `--strict` 下存在 warning |
| `2` | 参数错误、文件不存在、配置路径不存在、输出写入失败 |

`--strict` 的用途是把「未使用文献 / 缺字段」也变成门禁，适合在论文定稿前跑一遍；日常写作建议不开。

## 和 SARIF 的对应关系

`--format sarif` 输出 SARIF 2.1.0：`ruleId` 用 `MBG001` 这种稳定代码，`ruleIndex` 对应 `tool.driver.rules` 数组下标，`level` 是 `error` / `warning` / `note`（`info` 级诊断映射为 `note`），位置放在 `locations[0].physicalLocation`，路径统一为 `/` 分隔的 URI。

有错误时 `invocations[0].executionSuccessful` 为 `false`，警告不会影响该字段——这与退出码语义一致，避免「只有警告却报告运行失败」的误读。
