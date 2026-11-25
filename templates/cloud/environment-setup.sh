#!/bin/bash
# Cloud session setup for the attached akofink repos (dots, notes, akagent-cli).
# Finds the directory holding the checkouts, then delegates to dots, which links the
# repos into ~/dev/repos, builds akagent, exposes notes-task/syncdots, enables the dots
# git hooks, turns commit signing off, fixes PATH, and wires agent skills and instruction links.
# Best effort: a failure here must not block the session from starting.
#
# This file is the canonical copy of the setup script pasted into the Claude Code cloud
# environment settings and the OpenAI cloud environment settings. Edit it here, then paste.
for root in "$PWD" /workspace /home/user; do
  if [ -f "$root/dots/bin/cloud-session-setup.sh" ]; then
    bash "$root/dots/bin/cloud-session-setup.sh" --llm "$root" || echo "cloud-session-setup failed"
    break
  fi
done
true
