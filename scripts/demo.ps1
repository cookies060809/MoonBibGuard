# 一键演示：跑完六组场景并断言退出码，退出码非 0 表示有场景不符预期。
# 用法：powershell -ExecutionPolicy Bypass -File scripts/demo.ps1

$ErrorUtility = $null
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$env:Path = "$env:USERPROFILE\.moon\bin;$env:Path"
$moon = "moon"
if (-not (Get-Command moon -ErrorAction SilentlyContinue)) {
  $moon = Join-Path $env:USERPROFILE ".moon\bin\moon.exe"
  if (-not (Test-Path $moon)) {
    Write-Host "找不到 moon，请先安装 MoonBit 工具链：https://www.moonbitlang.com/download" -ForegroundColor Red
    exit 2
  }
}

Write-Host "1/2 构建 CLI ..." -ForegroundColor Cyan
& $moon build --target js | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Host "构建失败" -ForegroundColor Red
  exit 2
}

$js = Join-Path $root "_build\js\debug\build\cmd\main\main.js"
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) {
  Write-Host "找不到 node，请安装 Node.js 18+" -ForegroundColor Red
  exit 2
}

$cases = @(
  @{ name = "paper      单文档：1 错 1 警"; args = @("examples/paper.md", "examples/references.bib"); want = 1 },
  @{ name = "clean      全部正确"; args = @("examples/clean/paper.md", "--bib", "examples/clean/references.bib"); want = 0 },
  @{ name = "clean+strict 严格模式仍通过"; args = @("examples/clean/paper.md", "--bib", "examples/clean/references.bib", "--strict"); want = 0 },
  @{ name = "boundary   边界写法"; args = @("examples/boundary/paper.md", "--bib", "examples/boundary/references.bib"); want = 0 },
  @{ name = "broken     五类规则齐发"; args = @("examples/broken/paper.md", "--bib", "examples/broken/references.bib"); want = 1 },
  @{ name = "book       多文件 + @string"; args = @("examples/book/ch1-intro.md", "examples/book/ch2-method.md", "--bib", "examples/book/references.bib"); want = 1 }
)

Write-Host "2/2 运行场景 ..." -ForegroundColor Cyan
$failed = 0
foreach ($c in $cases) {
  & $node $js @($c.args) | Out-Null
  $code = $LASTEXITCODE
  if ($code -eq $c.want) {
    Write-Host ("  [通过] {0}（退出码 {1}）" -f $c.name, $code) -ForegroundColor Green
  } else {
    Write-Host ("  [失败] {0}（期望 {1}，实际 {2}）" -f $c.name, $c.want, $code) -ForegroundColor Red
    $failed++
  }
}

Write-Host ""
Write-Host "GitHub 注解格式预览："
& $node $js examples/book/ch1-intro.md examples/book/ch2-method.md --bib examples/book/references.bib --format github

if ($failed -gt 0) {
  Write-Host "`n$failed 个场景不符预期" -ForegroundColor Red
  exit 1
}
Write-Host "`n全部场景通过。" -ForegroundColor Green
exit 0
