import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const provider = "work-responses-proxy";
const id = "gpt-6.2-sol";
const api = "openai-responses";
const quote = (arg: string) => "'" + arg.replaceAll("'", "'\\''") + "'";

export default function (pi: ExtensionAPI) {
  const origin = process.env.PI_WORK_PROXY_ORIGIN;
  const helper = process.env.PI_WORK_PROXY_HELPER;
  if (!origin || !helper) throw new Error("Use the work proxy launcher to configure the provider.");
  const baseUrl = `${origin}/v1`;
  pi.registerProvider(provider, {
    api,
    baseUrl,
    apiKey: `!${quote(helper)} --base-url ${quote(origin)}`,
    models: [{
      id,
      name: "GPT-6.2 Sol (work proxy)",
      reasoning: true,
      thinkingLevelMap: { off: null, minimal: "low", low: "low", medium: "medium", high: "high", xhigh: "xhigh", max: "max" },
      input: ["text", "image"],
      // Pi's local catalog estimate, not the proxy's billing classification.
      cost: { input: 2, output: 10, cacheRead: 0.1, cacheWrite: 2.5 },
      contextWindow: 500_000,
      maxTokens: 128_000,
    }],
  });

  // These events cannot veto a selection by throwing; Pi logs extension errors
  // and continues. Exit only if the session would otherwise use a different route.
  const requireProxy = (model?: { provider: string; id: string; api: string; baseUrl: string }) => {
    if (model?.provider === provider && model.id === id && model.api === api && model.baseUrl === baseUrl) return;
    process.stderr.write("pi: work proxy route is unavailable or was changed; restart with pi --direct to use another route.\n");
    process.exit(2);
  };
  pi.on("session_start", (_event, ctx) => requireProxy(ctx.model));
  pi.on("model_select", (event) => requireProxy(event.model));
  pi.on("before_provider_request", (_event, ctx) => requireProxy(ctx.model));
}
