#!/bin/bash
# Cloud session setup for the attached akofink repos (dots, notes, akagent-cli).
# Finds the directory holding the checkouts, then delegates to dots, which links the
# repos into ~/dev/repos, builds akagent, exposes notes-task/syncdots, enables the dots
# git hooks, turns commit signing off, fixes PATH, and wires agent skills and instruction links.
# Best effort: a failure here must not block the session from starting.
#
# This file is the canonical copy of the setup script pasted into the Claude Code cloud
# environment settings and the OpenAI cloud environment settings. Edit it here, then paste.
# A cached container can hold stale checkouts (an OpenAI cloud session did), and a stale dots would not
# contain the scripts below, so bring clean checkouts up to origin/main first (fast-forward only).
for root in "$PWD" /workspace /home/user; do
  if [ -d "$root/dots/.git" ] || [ -f "$root/dots/.git" ]; then
    for repo in dots notes akagent-cli; do
      [ -e "$root/$repo/.git" ] || continue
      [ -z "$(git -C "$root/$repo" status --porcelain)" ] || continue
      git -C "$root/$repo" fetch -q origin main 2>/dev/null &&
        git -C "$root/$repo" merge-base --is-ancestor HEAD origin/main &&
        git -C "$root/$repo" merge -q --ff-only origin/main
    done
  fi
  if [ -f "$root/dots/bin/cloud-session-setup.sh" ]; then
    bash "$root/dots/bin/cloud-session-setup.sh" --llm "$root" || echo "cloud-session-setup failed"
    break
  fi
done
true
