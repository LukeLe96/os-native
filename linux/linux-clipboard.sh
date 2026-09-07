#!/usr/bin/env bash
# Linux Native Clipboard (Wayland wl-clipboard or X11 xclip)
if [ "$1" == "--copy" ] || [ "$1" == "-c" ]; then
  if command -v wl-copy >/dev/null 2>&1; then
    wl-copy "$2"
  elif command -v xclip >/dev/null 2>&1; then
    echo -n "$2" | xclip -selection clipboard
  fi
  echo "Copied to Linux clipboard!"
elif [ "$1" == "--paste" ] || [ "$1" == "-p" ]; then
  if command -v wl-paste >/dev/null 2>&1; then
    wl-paste
  elif command -v xclip >/dev/null 2>&1; then
    xclip -selection clipboard -o
  fi
fi
