#!/usr/bin/env bash
# Linux Native OCR using Tesseract (Standard Linux Open Source Engine)
if [ -z "$1" ]; then
  echo "Usage: linux-ocr.sh <image_path> [lang=vie+eng]"
  exit 1
fi
IMAGE="$1"
LANG="${2:-vie+eng}"
if command -v tesseract >/dev/null 2>&1; then
  tesseract "$IMAGE" stdout -l "$LANG" 2>/dev/null
else
  echo "Error: tesseract not installed. Install with: sudo apt-get install tesseract-ocr tesseract-ocr-vie"
  exit 1
fi
