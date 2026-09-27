#!/usr/bin/env python3
"""Provider events to tmux window status and local desktop notifications."""
import os
import shlex
import shutil
import subprocess
import sys

STATES = {"idle", "working", "blocked", "done", "waiting"}


def run(*args):
    return subprocess.run(args, capture_output=True, text=True, timeout=2, check=True).stdout.strip()


def macos_notification_command(state, label, tmux_path, socket_path, session_id, pane_id,
                               open_path="/usr/bin/open"):
    tmux = shlex.quote(tmux_path)
    socket = shlex.quote(socket_path)
    session = shlex.quote(session_id)
    pane = shlex.quote(pane_id)
    detached = " ".join(shlex.quote(value) for value in (
        tmux_path, "-S", socket_path, "attach-session", "-t", session_id,
        ";", "select-pane", "-t", pane_id))
    launch = " ".join(shlex.quote(value) for value in (
        open_path, "-na", "/Applications/Ghostty.app", "--args", "-e",
        "/bin/sh", "-lc", f"exec {detached}"))
    script = (
        f"tmux={tmux}; socket={socket}; session={session}; pane={pane}; "
        f"record=$(\"$tmux\" -S \"$socket\" list-clients "
        "-F '#{client_activity} #{client_name}' 2>/dev/null | "
        "/usr/bin/sort -nr | /usr/bin/head -n 1); "
        "client=${record#* }; "
        "if [ -n \"$client\" ]; then "
        "\"$tmux\" -S \"$socket\" switch-client -c \"$client\" -t \"$session\" && "
        "\"$tmux\" -S \"$socket\" select-pane -t \"$pane\"; "
        f"else {launch}; fi"
    )
    return ["terminal-notifier", "-title", label, "-message", state,
            "-activate", "com.mitchellh.ghostty", "-execute", script]


def tmux_server_binary(tmux, pane):
    resolved = shutil.which(tmux)
    if resolved:
        resolved = os.path.realpath(resolved)
    try:
        pid = run(tmux, "display-message", "-p", "-t", pane, "#{pid}")
        result = subprocess.run(["/usr/sbin/lsof", "-a", "-p", pid, "-d", "txt", "-Fn"],
                                capture_output=True, text=True, timeout=2, check=True)
        for line in result.stdout.splitlines():
            if line.startswith("n") and line[1:].endswith("/tmux"):
                return os.path.realpath(line[1:])
    except (OSError, subprocess.SubprocessError):
        pass
    if resolved:
        return resolved
    raise FileNotFoundError("cannot resolve tmux server executable")


def notify(state, label, tmux_path, socket_path, session_id, pane_id):
    if sys.platform == "darwin":
        subprocess.Popen(macos_notification_command(
            state, label, tmux_path, socket_path, session_id, pane_id),
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, start_new_session=True)
    elif sys.platform == "win32" or shutil.which("powershell.exe"):
        script = ("[Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime] > $null; "
                  "$xml = New-Object Windows.Data.Xml.Dom.XmlDocument; "
                  "$body = [System.Security.SecurityElement]::Escape($env:TMUX_AGENT_NOTIFY_BODY); "
                  "$xml.LoadXml('<toast><visual><binding template=\"ToastText01\"><text id=\"1\">' + $body + '</text></binding></visual></toast>'); "
                  "$toast = New-Object Windows.UI.Notifications.ToastNotification $xml; "
                  "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Windows PowerShell').Show($toast)")
        env = {**os.environ, "TMUX_AGENT_NOTIFY_BODY": f"{label}: {state}"}
        subprocess.Popen(["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script],
                         env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    elif shutil.which("notify-send") and (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")):
        subprocess.Popen(["notify-send", label, state], stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                         start_new_session=True)


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in STATES:
        return 2
    pane = os.environ.get("TMUX_PANE")
    if not pane:
        return 0
    try:
        tmux = os.environ.get("TMUX_AGENT_SIGNALS_TMUX", "tmux")
        window = run(tmux, "display-message", "-p", "-t", pane, "#{window_id}")
        if not window.startswith("@"):
            return 0
        before = run(tmux, "show-options", "-wqv", "-t", window, "@agent_state")
        state = sys.argv[1]
        after = "" if state in ("working", "idle") else state
        if before == after:
            return 0
        if after:
            run(tmux, "set-option", "-w", "-t", window, "@agent_state", after)
        else:
            run(tmux, "set-option", "-wu", "-t", window, "@agent_state")
        if after in ("blocked", "waiting", "done"):
            label = run(tmux, "display-message", "-p", "-t", pane, "#{window_name}")
            socket_path = run(tmux, "display-message", "-p", "-t", pane, "#{socket_path}")
            session_id = run(tmux, "display-message", "-p", "-t", pane, "#{session_id}")
            pane_id = run(tmux, "display-message", "-p", "-t", pane, "#{pane_id}")
            tmux_path = tmux_server_binary(tmux, pane)
            notify(after, label or "Agent", tmux_path, socket_path, session_id, pane_id)
    except (OSError, subprocess.SubprocessError):
        pass  # Hooks must not interrupt the provider if tmux is gone.
    return 0


if __name__ == "__main__":
    sys.exit(main())
