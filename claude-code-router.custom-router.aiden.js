// ~/.claude-code-router/custom-router.js — Aiden AIProxy 版本
// 把 Claude Code 的模型档位映射到 Aiden AIProxy 模型：
//   Opus  → deepseek-v4-pro  (1M 上下文，opus 档位)
//   Sonnet→ gpt-5.4          (Claude Code 默认，PTU)
//   Haiku → gpt-5.5-paygo    (按量付费)
// 返回 "provider,model"；返回 null 则回落到 config.json 的 Router.default。
module.exports = async function router(req, config) {
  const model = ((req && req.body && req.body.model) || "").toLowerCase();
  if (model.includes("haiku"))  return "trae-cn,gpt-5.5-paygo";
  if (model.includes("sonnet")) return "trae-cn,gpt-5.4";
  if (model.includes("opus"))   return "trae-cn,deepseek-v4-pro";
  return null;
};