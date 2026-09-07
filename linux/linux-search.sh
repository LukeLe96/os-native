#!/usr/bin/env bash
# Linux Fast Index Search using plocate or locate
if [ -z "$1" ]; then
  echo "Usage: linux-search.sh <pattern> [path_prefix]"
  exit 1
fi
PATTERN="$1"
PREFIX="${2:-}"

if command -v plocate >/dev/null 2>&1; then
  if [ -n "$PREFIX" ]; then
    plocate -i "$PATTERN" | grep "^$PREFIX"
  else
    plocate -i "$PATTERN"
  fi
elif command -v locate >/dev/null 2>&1; then
  if [ -n "$PREFIX" ]; then
    locate -i "$PATTERN" | grep "^$PREFIX"
  else
    locate -i "$PATTERN"
  fi
else
  echo "Neither plocate nor locate installed. Fallback to find:"
  find "${PREFIX:-.}" -iname "*$PATTERN*" 2>/dev/null
fi
