import { execFileSync } from "node:child_process";

// TUI-local attribution matters: the server may be shared by unrelated panes.
export default {
  id: "dots.tmux-agent-state",
  setup(api) {
    const pane = process.env.TMUX_PANE;
    if (!process.env.TMUX || !/^%\d+$/.test(pane ?? "")) return;
    const tmux = (...args) => execFileSync("tmux", args, { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    try {
      // Window-scoped badges cannot represent multiple agents in one window.
      if (tmux("list-panes", "-t", pane, "-F", "#{pane_id}").split("\n").length !== 1) return;
    } catch { return; }
    let selected;
    let state = "";
    let blockers = new Map();
    const deltas = new Map();
    let disposed = false;
    const root = (id) => {
      const seen = new Set();
      while (id && !seen.has(id)) {
        seen.add(id);
        const session = api.data.session.get(id);
        if (!session) return;
        if (!session.parentID) return id;
        id = session.parentID;
      }
    };
    const write = () => {
      if (disposed) return;
      try {
        if (tmux("list-panes", "-t", pane, "-F", "#{pane_id}").split("\n").length !== 1) return;
        if (blockers.size) tmux("set-option", "-w", "-t", pane, "@agent_state", "blocked");
        else if (state) tmux("set-option", "-w", "-t", pane, "@agent_state", state);
        else tmux("set-option", "-wu", "-t", pane, "@agent_state");
      } catch { /* tmux may have exited */ }
    };
    const sync = () => {
      const route = api.ui.router.current();
      const id = route.type === "session" ? root(route.sessionID) : undefined;
      const selectionChanged = id !== selected;
      if (selectionChanged) {
        selected = id;
        blockers.clear();
        deltas.clear();
        state = "";
      }
      const previous = blockers.size > 0;
      if (id) {
        const next = new Map();
        const hydrated = new Set();
        for (const member of [id, ...api.data.session.family(id)]) {
          for (const kind of ["permission", "form"]) {
            const items = api.data.session[kind].list(member);
            if (items === undefined) {
              for (const [key, owner] of blockers) if (owner === member && key.startsWith(`${kind}:`)) next.set(key, owner);
              continue;
            }
            hydrated.add(`${kind}:${member}`);
            for (const item of items) next.set(`${kind}:${item.id}`, member);
          }
        }
        for (const [key, delta] of deltas) {
          if (hydrated.has(`${delta.kind}:${delta.owner}`) && next.has(key) === delta.present) deltas.delete(key);
          else if (delta.present) next.set(key, delta.owner);
          else next.delete(key);
        }
        blockers = next;
      }
      if (selectionChanged || previous !== (blockers.size > 0)) write();
    };
    const change = (kind, request, owner, present) => {
      if (typeof request !== "string") return;
      const key = `${kind}:${request}`;
      deltas.set(key, { kind, owner, present });
      if (present) blockers.set(key, owner);
      else blockers.delete(key);
    };
    const unsubscribe = api.data.listen(({ details: event }) => {
      sync();
      const data = event.data;
      if (!data || !selected) return;
      if (event.type === "session.deleted") {
        for (const [key, owner] of blockers) if (owner === data.sessionID) blockers.delete(key);
        for (const [key, delta] of deltas) if (delta.owner === data.sessionID) deltas.delete(key);
        write();
        return;
      }
      const id = event.type === "form.created" ? data.form?.sessionID : data.sessionID;
      if (root(id) !== selected) return;
      switch (event.type) {
        case "permission.asked": change("permission", data.id, id, true); break;
        case "permission.replied": change("permission", data.requestID, id, false); break;
        case "form.created": change("form", data.form.id, id, true); break;
        case "form.replied":
        case "form.cancelled": change("form", data.id, id, false); break;
        case "session.execution.started": if (id === selected) state = ""; else return; break;
        case "session.execution.succeeded":
        case "session.execution.interrupted": if (id === selected) state = "done"; else return; break;
        case "session.execution.failed": if (id === selected) state = "blocked"; else return; break;
        default: return;
      }
      write();
    });
    sync();
    const poll = setInterval(sync, 250);
    return () => { disposed = true; clearInterval(poll); unsubscribe(); };
  },
};
