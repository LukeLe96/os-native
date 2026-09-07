#!/usr/bin/env bash
# Linux Native Docx text reader without LibreOffice (Direct OpenXML stream via unzip)
if [ -z "$1" ]; then
  echo "Usage: linux-docx.sh <file.docx>"
  exit 1
fi
unzip -p "$1" word/document.xml | sed -e 's/<[^>]*>/ /g' -e 's/  */ /g'
