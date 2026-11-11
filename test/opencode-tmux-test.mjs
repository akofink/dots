import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
import plugin from "../templates/dot_config/opencode/tmux-agent-state/tui.js";

const tmux = (...args) => execFileSync("tmux", args, { encoding: "utf8" }).trim();
if (process.argv[2] === "worker") {
  const pane = process.env.TMUX_PANE;
  const id = process.argv[3];
  let receive;
  const api = {
    ui: { router: { current: () => ({ type: "session", sessionID: id }) } },
    data: {
      listen: (fn) => { receive = fn; return () => {}; },
      session: { get: (sid) => sid === id ? { id } : sid === `${id}-child` ? { id: sid, parentID: id } : undefined, family: () => [],
        permission: { list: () => [] }, form: { list: () => [] } },
    },
  };
  const dispose = plugin.setup(api);
  const badge = () => tmux("show-option", "-wqv", "-t", pane, "@agent_state");
  const emit = (type, data) => receive({ details: { type, data } });
  assert.equal(badge(), "");
  emit("session.execution.started", { sessionID: id });
  assert.equal(badge(), "");
  emit("permission.asked", { sessionID: id, id: "permission" });
  assert.equal(badge(), "blocked");
  emit("form.created", { form: { sessionID: `${id}-child`, id: "form" } });
  emit("permission.replied", { sessionID: id, requestID: "permission" });
  assert.equal(badge(), "blocked");
  emit("form.cancelled", { sessionID: `${id}-child`, id: "form" });
  assert.equal(badge(), "");
  emit("session.execution.succeeded", { sessionID: id });
  assert.equal(badge(), "done");
  emit("permission.asked", { sessionID: "other", id: "unrelated" });
  assert.equal(badge(), "done");
  emit("session.execution.failed", { sessionID: id });
  assert.equal(badge(), "blocked");
  dispose();
  console.log(`${id}: idle, working, blocked, working, done; unrelated ignored`);
} else {
  assert(process.env.TMUX_PANE, "run inside tmux");
  const session = tmux("display-message", "-p", "-t", process.env.TMUX_PANE, "#{session_id}");
  const panes = [];
  try {
    for (let i = 0; i < 2; i++) panes.push(tmux("new-window", "-dP", "-F", "#{pane_id}", "-t", `${session}:`, "sleep 30"));
    const children = panes.map((pane, index) => spawn(process.execPath, [process.argv[1], "worker", `test-${index}`], {
      env: { ...process.env, TMUX_PANE: pane }, stdio: "inherit",
    }));
    await Promise.all(children.map((child) => new Promise((resolve, reject) => {
      child.on("error", reject);
      child.on("exit", (code) => code === 0 ? resolve() : reject(new Error(`worker exited ${code}`)));
    })));
  } finally {
    for (const pane of panes) tmux("kill-window", "-t", pane);
  }
}
