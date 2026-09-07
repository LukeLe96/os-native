#!/usr/bin/env bash
# Linux Native PDF text extraction & rendering using poppler-utils
CMD="$1"
PDF="$2"

if [ "$CMD" == "extract" ]; then
  pdftotext "$PDF" -
elif [ "$CMD" == "render" ]; then
  OUT_DIR="${3:-./pdf_out}"
  mkdir -p "$OUT_DIR"
  pdftoppm -png -r 150 "$PDF" "$OUT_DIR/page"
  echo "Rendered PDF to $OUT_DIR"
else
  echo "Usage:"
  echo "  linux-pdf.sh extract <file.pdf>"
  echo "  linux-pdf.sh render <file.pdf> [output_dir]"
  exit 1
fi
