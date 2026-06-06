// ~/.claude-code-router/custom-router.js — Trae CN 网关版本
// 把 Claude Code 的模型档位映射到 Trae CN 内部模型：
//   Opus  → openrouter-2o
//   Sonnet→ openrouter-1o
//   Haiku → openrouter-1
// 返回 "provider,model"；返回 null 则回落到 config.json 的 Router.default。
module.exports = async function router(req, config) {
  const model = ((req && req.body && req.body.model) || "").toLowerCase();
  if (model.includes("haiku"))  return "trae-cn,openrouter-1";
  if (model.includes("sonnet")) return "trae-cn,openrouter-1o";
  if (model.includes("opus"))   return "trae-cn,openrouter-2o";
  return null;
};