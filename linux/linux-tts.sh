#!/usr/bin/env bash
# Linux Native TTS using spd-say or espeak-ng
if [ -z "$1" ]; then
  echo "Usage: linux-tts.sh <text> [output_file.wav]"
  exit 1
fi
TEXT="$1"
OUT="${2:-}"

if [ -n "$OUT" ]; then
  if command -v espeak-ng >/dev/null 2>&1; then
    espeak-ng -v vi -w "$OUT" "$TEXT"
    echo "Synthesized audio to $OUT with espeak-ng"
  elif command -v piper >/dev/null 2>&1; then
    echo "$TEXT" | piper --output_file "$OUT"
    echo "Synthesized audio to $OUT with piper"
  fi
else
  if command -v spd-say >/dev/null 2>&1; then
    spd-say "$TEXT"
  elif command -v espeak-ng >/dev/null 2>&1; then
    espeak-ng -v vi "$TEXT"
  fi
fi
