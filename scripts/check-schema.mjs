// 校验 CLI 的 JSON / SARIF 输出是否符合 schema/*.schema.json。
// 只实现本项目 schema 用到的关键字：type / required / properties /
// additionalProperties / items / enum / const / pattern / minimum / minLength。
// 不引入 ajv 之类的依赖，保证离线可跑。
//
// 用法：node scripts/check-schema.mjs

import fs from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const cli = path.join(root, "_build", "js", "debug", "build", "cmd", "main", "main.js");
const tmp = path.join(root, "_bench", "schema-check.json");

const failures = [];

function typeOf(value) {
  if (Array.isArray(value)) return "array";
  if (value === null) return "null";
  if (typeof value === "number") return Number.isInteger(value) ? "integer" : "number";
  return typeof value;
}

function validate(value, schema, where) {
  if (schema.const !== undefined && value !== schema.const) {
    failures.push(`${where}: 期望常量 ${JSON.stringify(schema.const)}，实际 ${JSON.stringify(value)}`);
    return;
  }
  if (schema.enum && !schema.enum.includes(value)) {
    failures.push(`${where}: ${JSON.stringify(value)} 不在枚举 ${JSON.stringify(schema.enum)} 内`);
    return;
  }
  if (schema.type) {
    const actual = typeOf(value);
    const ok = schema.type === "number" ? actual === "number" || actual === "integer" : actual === schema.type;
    if (!ok) {
      failures.push(`${where}: 期望类型 ${schema.type}，实际 ${actual}`);
      return;
    }
  }
  if (typeof value === "string") {
    if (schema.minLength && value.length < schema.minLength) failures.push(`${where}: 字符串太短`);
    if (schema.pattern && !new RegExp(schema.pattern).test(value)) failures.push(`${where}: 不匹配 ${schema.pattern}`);
  }
  if (typeof value === "number" && schema.minimum !== undefined && value < schema.minimum) {
    failures.push(`${where}: ${value} 小于最小值 ${schema.minimum}`);
  }
  if (Array.isArray(value) && schema.items) {
    value.forEach((item, i) => validate(item, schema.items, `${where}[${i}]`));
  }
  if (typeOf(value) === "object") {
    for (const key of schema.required ?? []) {
      if (!(key in value)) failures.push(`${where}: 缺少必需字段 ${key}`);
    }
    const props = schema.properties ?? {};
    for (const [key, item] of Object.entries(value)) {
      if (props[key]) {
        validate(item, props[key], `${where}.${key}`);
      } else if (schema.additionalProperties === false) {
        failures.push(`${where}: 不允许的字段 ${key}`);
      } else if (typeof schema.additionalProperties === "object") {
        validate(item, schema.additionalProperties, `${where}.${key}`);
      }
    }
  }
}

function checkOutput(schemaFile, args, label) {
  const r = spawnSync(process.execPath, [cli, ...args], { cwd: root, encoding: "utf8" });
  if (r.status !== 0 && r.status !== 1) {
    failures.push(`${label}: CLI 退出码异常 ${r.status}`);
    return;
  }
  let parsed;
  try {
    parsed = JSON.parse(r.stdout);
  } catch (e) {
    failures.push(`${label}: 输出不是合法 JSON（${e.message}）`);
    return;
  }
  const schema = JSON.parse(fs.readFileSync(path.join(root, "schema", schemaFile), "utf8"));
  validate(parsed, schema, label);
  console.log(`${label}: 结构校验完成`);
}

// 1) JSON 报告：带诊断的样例
checkOutput(
  "report.schema.json",
  ["examples/paper.md", "examples/references.bib", "--json"],
  "report(paper)"
);

// 2) JSON 报告：无诊断的样例（diagnostics 为空数组也应通过）
checkOutput(
  "report.schema.json",
  ["examples/clean/paper.md", "--bib", "examples/clean/references.bib", "--json"],
  "report(clean)"
);

// 3) SARIF：结构由 schema 之外的手写断言保证（SARIF 官方 schema 太大，不内联）
const sarifRun = spawnSync(process.execPath, [cli, "examples/paper.md", "examples/references.bib", "--format", "sarif"], {
  cwd: root,
  encoding: "utf8",
});
try {
  const sarif = JSON.parse(sarifRun.stdout);
  if (sarif.version !== "2.1.0") failures.push("sarif: version 不是 2.1.0");
  if (!sarif.runs?.[0]?.tool?.driver?.rules?.length) failures.push("sarif: 缺少 rules");
  for (const res of sarif.runs[0].results ?? []) {
    if (!["error", "warning", "note"].includes(res.level)) failures.push(`sarif: 非法 level ${res.level}`);
    if (!res.locations?.[0]?.physicalLocation?.artifactLocation?.uri) failures.push(`sarif: ${res.ruleId} 缺少 uri`);
  }
  console.log("sarif: 结构校验完成");
} catch (e) {
  failures.push(`sarif: 输出不是合法 JSON（${e.message}）`);
}

// 4) 配置文件 schema：用仓库里的示例配置
const configPath = path.join(root, "examples", "paper-project", ".moonbibguard.json");
if (fs.existsSync(configPath)) {
  const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
  const schema = JSON.parse(fs.readFileSync(path.join(root, "schema", "config.schema.json"), "utf8"));
  validate(config, schema, "config");
  console.log("config: 结构校验完成");
}

if (fs.existsSync(tmp)) fs.rmSync(tmp);

if (failures.length) {
  console.error(`\n${failures.length} 处不符合 schema：`);
  for (const f of failures) console.error(`  - ${f}`);
  process.exit(1);
}
console.log("\n全部输出符合 schema。");
