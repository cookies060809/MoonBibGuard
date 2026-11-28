# 与 Pandoc 的兼容性说明

Pandoc 的 Markdown 引用语法是 MoonBibGuard 的对齐目标，但**本项目不是 Pandoc 的替代品**：Pandoc 负责渲染与 citeproc 处理，MoonBibGuard 只负责「正文引用键 ↔ 文献库条目」的一致性检查。

## 1. 对齐的语法形态

以下形态依据 Pandoc 官方手册（Citations 一节）整理，并在 `citation_test.mbt` 中每条都有对应断言：

| Markdown 写法 | Pandoc 语义 | MoonBibGuard 的抽取结果 |
| --- | --- | --- |
| `[@smith2024]` | 普通引用 | key = `smith2024` |
| `[@a; @b]` | 同一括号多条引用 | 两条，各自记录位置 |
| `[@a;@b]` | 同上，无空格 | 两条 |
| `[-@smith2024]` | 作者在场（抑制作者名） | key = `smith2024` |
| `[see @a, ch. 3]` | 带前缀与定位 | key = `a`，前缀与定位被忽略 |
| `[@a, pp. 12-15]` | 页码定位 | key = `a`，`pp. 12-15` 不会被当成键 |
| `[**@b**]` | 强调包裹 | key = `b` |
| `[见 [@inner]]` | 方括号嵌套 | key = `inner` |
| 围栏代码块内的 `[@x]` | 代码，不是引用 | 不抽取 |
| 行内代码 `` `[@x]` `` | 代码，不是引用 | 不抽取 |
| `foo@bar.com` | 普通文本 | 不抽取 |

**明确的差异（有意为之）**：

1. **定位信息不保留**。Pandoc 会把 `pp. 12-15` 解析成 citation 的 locator；我们只保留键与位置，因为本工具的目标是键的一致性，不是渲染。定位信息存在不会影响判定，也不会污染键。
2. **正文裸写的 `@smith2024` 不视为引用**。Pandoc 支持这种 in-text 形式，但它与邮箱、@ 用户名高度混淆；本工具只在 `[...]` 内识别，宁可少报也不误报。这是已知限制，写在 README 里。
3. **不支持 `\cite{}`**。那是 LaTeX 语法，不在范围内。

## 2. 没有做运行时差异对照的原因

本机（Windows 开发环境）**没有安装 Pandoc**，所以没有跑过「同一份 Markdown 交给 Pandoc 与交给 MoonBibGuard，比对抽取出的键集合」这种运行时对照。为了避免夸大，仓库里不提供未经运行验证的对照脚本，只提供：

- 上表的语义用例（已在单元测试中固化）；
- 下面这份可复现的对照方法，供有 Pandoc 的环境自行执行。

## 3. 如何自行做运行时对照

```bash
# 1) 准备一份样例
cat > /tmp/cite.md <<'EOF'
甲 [@a, pp. 1-2]；乙 [@b]；丙 [-@c]；代码 `[@fake]`。
EOF

# 2) 让 Pandoc 输出 AST，并抽出 Cite 里的键
pandoc /tmp/cite.md -f markdown -t json | node -e '
let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
  const keys=[];
  (function walk(x){
    if(Array.isArray(x)){
      if(x[0]==="Cite") for(const c of x[1].citations) keys.push(c.id);
      x.forEach(walk);
    } else if(x&&typeof x==="object") Object.values(x).forEach(walk);
  })(JSON.parse(s));
  console.log(keys.join(","));
});'

# 3) 让 MoonBibGuard 输出 JSON，并抽出键（需要一条占位文献库，避免 MBG001 干扰查看）
node _build/js/debug/build/cmd/main/main.js /tmp/cite.md --bib /tmp/refs.bib --json | \
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).summary.citations))'
```

预期：Pandoc 抽到 `a,b,c`；MoonBibGuard 的 `citations` 计数为 3（代码里的 `[@fake]` 两者都不计）。

如果将来两者的键集合出现分歧，正确做法是先确认 Pandoc 手册的语义，再决定改实现还是把差异写进本节——**不把 Pandoc 的行为当作唯一真理**，尤其是在 BibTeX 解析语义上（Pandoc 依赖 citeproc 与 CSL，字段要求与 BibTeX 条目类型并不一一对应）。

## 4. 与 citeproc 的分工

`pandoc --citeproc` 在缺少引用键时通常渲染成 `[?]` 或直接报错，属于「渲染期失败」；MoonBibGuard 把同一类问题提前到「写作期」，给出文件 / 行 / 列与相近键建议。两者可以串起来用：先 `mbg` 过一遍，再交给 Pandoc 渲染。
