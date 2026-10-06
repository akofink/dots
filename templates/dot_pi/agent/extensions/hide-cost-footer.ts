import { relative, resolve, sep, isAbsolute } from "node:path";

const visibleText = (text: string): string => text.replace(/\u001b\[[0-9;]*m/g, "");
const visibleWidth = (text: string): number => Array.from(visibleText(text)).length;
const truncateToWidth = (text: string, width: number, suffix = "..."): string => {
  if (visibleWidth(text) <= width) return text;
  const plain = visibleText(text);
  return Array.from(plain).slice(0, Math.max(0, width - suffix.length)).join("") + suffix;
};

const formatTokens = (count: number): string => {
  if (count < 1_000) return `${count}`;
  if (count < 10_000) return `${(count / 1_000).toFixed(1)}k`;
  if (count < 1_000_000) return `${Math.round(count / 1_000)}k`;
  if (count < 10_000_000) return `${(count / 1_000_000).toFixed(1)}M`;
  return `${Math.round(count / 1_000_000)}M`;
};

function formatCwd(cwd: string, home: string | undefined): string {
  if (!home) return cwd;
  const relativeToHome = relative(resolve(home), resolve(cwd));
  const insideHome = relativeToHome === "" ||
    (relativeToHome !== ".." && !relativeToHome.startsWith(`..${sep}`) && !isAbsolute(relativeToHome));
  return insideHome ? (relativeToHome === "" ? "~" : `~${sep}${relativeToHome}`) : cwd;
}

export default function (pi: any) {
  // Subscription-based personal use makes catalog-price dollars misleading; keep the other footer stats.
  if ((process.env.MACHINE_CLASS || "personal") !== "personal") return;

  pi.on("session_start", async (_event, ctx) => {
    ctx.ui.setFooter((tui, theme, footerData) => {
      const unsubscribe = footerData.onBranchChange(() => tui.requestRender());
      return {
        dispose: unsubscribe,
        invalidate() {},
        render(width: number): string[] {
          let input = 0;
          let output = 0;
          let cacheRead = 0;
          let cacheWrite = 0;
          let latestCacheHitRate: number | undefined;
          let latestResponseModel: string | undefined;
          for (const entry of ctx.sessionManager.getEntries()) {
            const usage = entry.type === "message" && entry.message.role === "assistant"
              ? entry.message.usage
              : entry.type === "message" && entry.message.role === "toolResult"
                ? entry.message.usage
                : entry.type === "usage" || entry.type === "compaction" || entry.type === "branch_summary"
                  ? entry.usage
                  : undefined;
            if (!usage) continue;
            input += usage.input;
            output += usage.output;
            cacheRead += usage.cacheRead;
            cacheWrite += usage.cacheWrite;
            if (entry.type === "message" && entry.message.role === "assistant") {
              const promptTokens = usage.input + usage.cacheRead + usage.cacheWrite;
              latestCacheHitRate = promptTokens > 0 ? usage.cacheRead / promptTokens * 100 : undefined;
              latestResponseModel = entry.message.responseModel;
            }
          }

          let cwd = formatCwd(ctx.sessionManager.getCwd(), process.env.HOME || process.env.USERPROFILE);
          const branch = footerData.getGitBranch();
          if (branch) cwd += ` (${branch})`;
          const sessionName = ctx.sessionManager.getSessionName();
          if (sessionName) cwd += ` • ${sessionName}`;

          const stats: string[] = [];
          if (input) stats.push(`↑${formatTokens(input)}`);
          if (output) stats.push(`↓${formatTokens(output)}`);
          if (cacheRead) stats.push(`R${formatTokens(cacheRead)}`);
          if (cacheWrite) stats.push(`W${formatTokens(cacheWrite)}`);
          if ((cacheRead || cacheWrite) && latestCacheHitRate !== undefined) {
            stats.push(`CH${latestCacheHitRate.toFixed(1)}%`);
          }
          const context = ctx.getContextUsage();
          const contextWindow = context?.contextWindow ?? ctx.model?.contextWindow ?? 0;
          const contextPercent = context?.percent == null ? "?" : `${context.percent.toFixed(1)}%`;
          const contextText = contextPercent === "?"
            ? `?/${formatTokens(contextWindow)} (auto)`
            : `${contextPercent}/${formatTokens(contextWindow)} (auto)`;
          stats.push(context && context.percent !== null && context.percent > 90
            ? theme.fg("error", contextText)
            : context && context.percent !== null && context.percent > 70
              ? theme.fg("warning", contextText)
              : contextText);
          if (process.env.PI_EXPERIMENTAL === "1") stats.push(`${theme.fg("dim", "•")} ${theme.bold(theme.fg("warning", "xp"))}`);

          let left = theme.fg("dim", stats.join(" "));
          const modelName = ctx.model?.id || "no-model";
          let rightText = ctx.model?.reasoning
            ? `${modelName} • ${ctx.thinkingLevel || "off"}`
            : modelName;
          if (latestResponseModel && latestResponseModel !== modelName) rightText += ` → ${latestResponseModel}`;
          const right = theme.fg("dim", rightText);
          const providerPrefix = ctx.model && footerData.getAvailableProviderCount() > 1
            ? `(${ctx.model.provider}) `
            : "";
          rightText = `${providerPrefix}${right}`;
          if (visibleWidth(left) + 2 + visibleWidth(rightText) > width && providerPrefix) rightText = right;
          if (visibleWidth(left) > width) left = truncateToWidth(left, width, "...");
          const padding = " ".repeat(Math.max(0, width - visibleWidth(left) - visibleWidth(rightText)));
          const statsLine = truncateToWidth(left + padding + rightText, width);
          const statuses = [...footerData.getExtensionStatuses().values()]
            .map((text) => text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim())
            .filter(Boolean);
          return [truncateToWidth(theme.fg("dim", cwd), width), statsLine, ...(statuses.length ? [truncateToWidth(statuses.join(" "), width)] : [])];
        },
      };
    });
  });
}
