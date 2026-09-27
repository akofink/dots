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


def macos_notification_command(state, label, session, window, pane, client=None):
    target_client = ["-c", client] if client else []
    jump = " ".join(shlex.quote(value) for value in (
        "tmux", "switch-client", *target_client, "-t", f"{session}:{window}"))
    select = " ".join(shlex.quote(value) for value in (
        "tmux", "select-pane", "-t", pane))
    return ["terminal-notifier", "-title", label, "-message", state,
            "-activate", "com.mitchellh.ghostty", "-execute", f"{jump} && {select}"]


def notify(state, label, session=None, window=None, pane=None, client=None):
    if sys.platform == "darwin":
        if not all((session, window, pane, client)) or not shutil.which("terminal-notifier"):
            subprocess.Popen(["open", "-a", "com.mitchellh.ghostty"],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
            return
        subprocess.Popen(macos_notification_command(state, label, session, window, pane, client),
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
    if os.environ.get("HERDR_ENV") == "1" or not pane:
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
            session = run(tmux, "display-message", "-p", "-t", pane, "#{session_name}")
            window_index = run(tmux, "display-message", "-p", "-t", pane, "#{window_index}")
            client = run(tmux, "display-message", "-p", "-t", pane, "#{client_name}")
            if client:
                notify(after, label or "Agent", session, window_index, pane, client)
            else:
                notify(after, label or "Agent", session, window_index, pane)
    except (OSError, subprocess.SubprocessError):
        pass  # Hooks must not interrupt the provider if tmux is gone.
    return 0


if __name__ == "__main__":
    sys.exit(main())
