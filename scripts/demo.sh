#!/usr/bin/env bash
# 一键演示：跑完八组场景并断言退出码，退出码非 0 表示有场景不符预期。
# 用法：bash scripts/demo.sh

set -u
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

export PATH="$HOME/.moon/bin:$PATH"
command -v moon >/dev/null 2>&1 || {
  echo "找不到 moon，请先安装 MoonBit 工具链：https://www.moonbitlang.com/download" >&2
  exit 2
}
command -v node >/dev/null 2>&1 || {
  echo "找不到 node，请安装 Node.js 18+" >&2
  exit 2
}

echo "1/2 构建 CLI ..."
moon build --target js >/dev/null || {
  echo "构建失败" >&2
  exit 2
}
js="$root/_build/js/debug/build/cmd/main/main.js"

run_case() {
  local name="$1" want="$2"
  shift 2
  node "$js" "$@" >/dev/null
  local code=$?
  if [ "$code" -eq "$want" ]; then
    echo "  [通过] $name（退出码 $code）"
  else
    echo "  [失败] $name（期望 $want，实际 $code）"
    FAILED=$((FAILED + 1))
  fi
}

echo "2/2 运行场景 ..."
FAILED=0
run_case "paper          单文档：1 错 1 警" 1 examples/paper.md examples/references.bib
run_case "clean          全部正确" 0 examples/clean/paper.md --bib examples/clean/references.bib
run_case "clean+strict   严格模式仍通过" 0 examples/clean/paper.md --bib examples/clean/references.bib --strict
run_case "boundary       边界写法" 0 examples/boundary/paper.md --bib examples/boundary/references.bib
run_case "broken         五类规则齐发" 1 examples/broken/paper.md --bib examples/broken/references.bib
run_case "book           多文件 + @string" 1 examples/book/ch1-intro.md examples/book/ch2-method.md --bib examples/book/references.bib
run_case "paper-project  仿真实论文 + 配置文件" 0 examples/paper-project/intro.md examples/paper-project/method.md --config examples/paper-project/.moonbibguard.json
run_case "sarif          SARIF 报告（paper）" 1 examples/paper.md examples/references.bib --format sarif

echo
echo "GitHub 注解格式预览："
node "$js" examples/book/ch1-intro.md examples/book/ch2-method.md --bib examples/book/references.bib --format github

if [ "${FAILED:-0}" -gt 0 ]; then
  echo
  echo "$FAILED 个场景不符预期" >&2
  exit 1
fi
echo
echo "全部场景通过。"
