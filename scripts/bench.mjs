// 生成合成数据集并测量 CLI 端到端耗时。
// 用法：node scripts/bench.mjs [规模 ...]（默认 100 1000 5000 10000）
// 输出：每一规模的最小 / 平均耗时，以及每次运行的退出码。

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const cli = path.join(root, "_build", "js", "debug", "build", "cmd", "main", "main.js");
const work = path.join(root, "_bench");

if (!fs.existsSync(cli)) {
  console.error("找不到 CLI，请先运行: moon build --target js");
  process.exit(2);
}

const sizes = process.argv.slice(2).map((s) => Number(s)).filter((n) => n > 0);
const targets = sizes.length > 0 ? sizes : [100, 1000, 5000, 10000];

function writeDataset(n) {
  fs.mkdirSync(work, { recursive: true });
  const bib = [];
  const md = [];
  for (let i = 0; i < n; i++) {
    bib.push(
      `@article{key${i},\n  author = {Author ${i} and Coauthor ${i}},\n  title = {A Study of Topic ${i} with Nested {Braces}},\n  journal = {Journal of Synthetic Results},\n  year = {${2000 + (i % 24)}}\n}`
    );
  }
  fs.writeFileSync(path.join(work, "refs.bib"), bib.join("\n\n") + "\n");

  for (let i = 0; i < n; i++) {
    md.push(`第 ${i + 1} 段：相关结论见 [@key${i}, p. ${i % 40 + 1}]。`);
    if (i % 6 === 5) md.push("");
  }
  fs.writeFileSync(path.join(work, "paper.md"), md.join("\n") + "\n");
  return { bibBytes: fs.statSync(path.join(work, "refs.bib")).size, mdBytes: fs.statSync(path.join(work, "paper.md")).size };
}

function runOnce() {
  const started = process.hrtime.bigint();
  const r = spawnSync(process.execPath, [cli, "paper.md", "refs.bib", "--quiet"], {
    cwd: work,
    encoding: "utf8",
  });
  const ms = Number(process.hrtime.bigint() - started) / 1e6;
  return { ms, code: r.status };
}

console.log("规模\tBibTeX\tMarkdown\t最小(ms)\t平均(ms)\t退出码");
for (const n of targets) {
  const meta = writeDataset(n);
  const runs = [];
  for (let i = 0; i < 3; i++) runs.push(runOnce());
  const min = Math.min(...runs.map((r) => r.ms));
  const avg = runs.reduce((a, r) => a + r.ms, 0) / runs.length;
  console.log(
    `${n}\t${(meta.bibBytes / 1024).toFixed(1)} KB\t${(meta.mdBytes / 1024).toFixed(1)} KB\t${min.toFixed(1)}\t${avg.toFixed(1)}\t${runs[0].code}`
  );
}
