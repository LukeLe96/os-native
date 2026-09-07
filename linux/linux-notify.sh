#!/usr/bin/env bash
# Linux Desktop Notification via libnotify
TITLE="${1:-Notification}"
MSG="${2:-Task complete}"
if command -v notify-send >/dev/null 2>&1; then
  notify-send "$TITLE" "$MSG"
  echo "Linux notification sent: [$TITLE] $MSG"
else
  echo "notify-send not found. Install libnotify-bin."
fi
