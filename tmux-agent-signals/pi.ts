import { spawn } from "node:child_process";
import path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  if (process.env.HERDR_ENV === "1" || !process.env.TMUX_PANE) return;

  const reporter = path.join(process.env.HOME || "", ".local/bin/tmux-agent-state");
  let chain = Promise.resolve();
  let active = false;
  let blocked = 0;
  let last = "";
  let started = false;

  function publish(state: string) {
    if (last === state) return;
    last = state;
    chain = chain.then(() => new Promise<void>((resolve) => {
      const child = spawn(reporter, [state], { stdio: "ignore" });
      child.on("error", () => resolve());
      child.on("exit", () => resolve());
    }));
  }
  function update() { publish(blocked ? "blocked" : active ? "working" : "idle"); }

  pi.on("session_start", (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    started = true;
    active = ctx.isIdle?.() === false;
    update();
  });
  pi.on("agent_start", () => { if (started) { active = true; update(); } });
  pi.on("agent_settled", (_event, ctx) => {
    if (started && ctx.isIdle?.() === true) { active = false; publish(blocked ? "blocked" : "done"); }
  });
  pi.events.on("herdr:blocked", (data: { active?: boolean }) => {
    if (!started) return;
    blocked = Math.max(0, blocked + (data?.active ? 1 : -1));
    update();
  });
  pi.on("session_shutdown", () => { if (started) publish("idle"); });
}
