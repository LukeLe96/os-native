#!/usr/bin/env bash
# Linux Sleep Inhibitor using systemd-inhibit (equivalent to macOS caffeinate)
if [ -z "$1" ]; then
  echo "Usage: linux-caffeinate.sh <command...>"
  echo "Prevents system sleep/idle while executing command."
  exit 1
fi

if command -v systemd-inhibit >/dev/null 2>&1; then
  systemd-inhibit --why="Hermes Agent Heavy Task" --what="idle:sleep" --mode="block" "$@"
else
  # Fallback: run command directly if systemd not active
  "$@"
fi
