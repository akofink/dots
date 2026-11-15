#!/usr/bin/env python3
"""Provider events to tmux window status and local desktop notifications."""
import os
import shutil
import subprocess
import sys

STATES = {"idle", "working", "blocked", "done", "waiting"}


def run(*args):
    return subprocess.run(args, capture_output=True, text=True, timeout=2, check=True).stdout.strip()


def notify(state, label):
    if sys.platform == "darwin":
        return
    if sys.platform == "win32" or shutil.which("powershell.exe"):
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
        # A hook run takes the badge over from any task heartbeat: drop its ownership marker even when the
        # value is unchanged, in the same tmux command as the write so a heartbeat cannot interleave.
        write = (["set-option", "-w", "-t", window, "@agent_state", after] if after
                 else ["set-option", "-wu", "-t", window, "@agent_state"])
        run(tmux, *write, ";", "set-option", "-wu", "-t", window, "@agent_state_task")
        if before == after:
            return 0
        if after in ("blocked", "waiting", "done"):
            label = run(tmux, "display-message", "-p", "-t", pane, "#{window_name}")
            notify(after, label or "Agent")
    except (OSError, subprocess.SubprocessError):
        pass  # Hooks must not interrupt the provider if tmux is gone.
    return 0


if __name__ == "__main__":
    sys.exit(main())
