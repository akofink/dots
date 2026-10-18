# Windows-native agent guidance

This is the global guidance for native Windows Claude Code and Codex sessions. Use Windows-native paths and tools for files under the Windows profile. Do not assume a WSL home directory is a Windows home directory, and do not symlink a WSL `~/.claude` or `~/.codex` directory across filesystems. Shared skills in this setup are copied into native Windows config directories.

## WSL operations

Use WSL only for work intentionally owned by the Linux environment. For multi-step notes or akagent operations, put the commands in a script file and pass that file to `wsl.exe`; do not compose nested PowerShell, WSL, and shell quoting. Example PowerShell invocation:

```powershell
wsl.exe --distribution Ubuntu --exec bash /home/<linux-user>/bin/notes-task.sh
```

The script should contain ordinary shell commands, use `set -euo pipefail`, and validate any arguments before acting. Keep notes and akagent commands in that script, not in a nested `-c` string. Use absolute Linux paths when practical. The distribution and Linux username above are placeholders to replace for the machine.

For example, a reviewed script can contain:

```bash
#!/usr/bin/env bash
set -euo pipefail
notes-task open my-task
akagent task inspect my-task
```

Do not use this guidance to access another user's files or to interact with another agent or session. Treat WSL and Windows as distinct environments and verify which side owns a path before modifying it.
