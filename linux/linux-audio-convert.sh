#!/usr/bin/env bash
# Linux Native Audio Converter using sox or ffmpeg
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: linux-audio-convert.sh <input_audio> <output_audio>"
  exit 1
fi
INPUT="$1"
OUTPUT="$2"

if command -v sox >/dev/null 2>&1; then
  sox "$INPUT" "$OUTPUT"
  echo "Converted with sox: $INPUT -> $OUTPUT"
elif command -v ffmpeg >/dev/null 2>&1; then
  ffmpeg -y -i "$INPUT" "$OUTPUT" -loglevel error
  echo "Converted with ffmpeg: $INPUT -> $OUTPUT"
else
  echo "Neither sox nor ffmpeg found. Install sox with: sudo apt install sox"
  exit 1
fi
