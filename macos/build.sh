#!/usr/bin/env bash
# build.sh: Compile os-native macOS Swift sources (macos/src/*.swift) into native ARM64 binaries (macos/bin/).
# Part of the Zero-Token Native OS Superpower Suite.
#
# Usage:
#   ./build.sh                       Build all tools (same as --all)
#   ./build.sh --all                 Build all tools
#   ./build.sh apple-embed apple-ocr-json   Build specific tools
#   ./build.sh --list                List buildable tools
#   ./build.sh --out-dir <dir> ...   Write binaries to <dir> instead of macos/bin
#   ./build.sh --debug ...           Build without optimizations (-Onone -g)
#
# Notes:
#   - Source names map to binary names by replacing '_' with '-' (apple_ocr_json.swift -> apple-ocr-json).
#   - Sources declaring '@main' are compiled with -parse-as-library; sources using top-level code are not
#     (-parse-as-library forbids top-level statements).
#   - Binaries without a Swift source (e.g. apple-ocr, apple-barcode) are never touched.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
OUT_DIR="$SCRIPT_DIR/bin"
OPT_FLAGS=(-O)
TARGETS=()

if [ -t 1 ]; then
  GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
else
  GREEN=""; RED=""; YELLOW=""; BOLD=""; RESET=""
fi

usage() {
  sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

tool_name() {
  local base
  base="$(basename "$1" .swift)"
  echo "${base//_/-}"
}

source_for() {
  local tool="$1" f
  for f in "$SRC_DIR"/*.swift; do
    if [ "$(tool_name "$f")" = "$tool" ]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

list_tools() {
  local f
  for f in "$SRC_DIR"/*.swift; do
    tool_name "$f"
  done | sort
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --list) list_tools; exit 0 ;;
    --all) shift ;;
    --debug) OPT_FLAGS=(-Onone -g); shift ;;
    --out-dir)
      if [ -z "${2:-}" ]; then echo "Error: --out-dir requires a directory" >&2; exit 2; fi
      OUT_DIR="$2"; shift 2 ;;
    -*) echo "Error: unknown option '$1'" >&2; usage >&2; exit 2 ;;
    *) TARGETS+=("$1"); shift ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "${RED}Error:${RESET} macOS tools can only be built on Darwin (detected: $(uname -s))." >&2
  exit 1
fi

if ! command -v swiftc >/dev/null 2>&1; then
  echo "${RED}Error:${RESET} swiftc not found. Install Xcode Command Line Tools: xcode-select --install" >&2
  exit 1
fi

if [ ! -d "$SRC_DIR" ]; then
  echo "${RED}Error:${RESET} source directory not found: $SRC_DIR" >&2
  exit 1
fi

SOURCES=()
if [ ${#TARGETS[@]} -eq 0 ]; then
  for f in "$SRC_DIR"/*.swift; do SOURCES+=("$f"); done
else
  for t in "${TARGETS[@]}"; do
    t="$(basename "$t" .swift)"; t="${t//_/-}"
    if src="$(source_for "$t")"; then
      SOURCES+=("$src")
    else
      echo "${RED}Error:${RESET} no Swift source for '$t'. Buildable tools:" >&2
      list_tools | sed 's/^/  /' >&2
      exit 2
    fi
  done
fi

mkdir -p "$OUT_DIR"
LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

TOTAL=${#SOURCES[@]}
ARCH="$(uname -m)"
echo "${BOLD}os-native macOS build${RESET}: $TOTAL tool(s) | $(swiftc --version 2>&1 | head -1 | sed 's/^.*\(Apple Swift version [0-9.]*\).*$/\1/') | $ARCH | ${OPT_FLAGS[*]}"
echo "Output: $OUT_DIR"

OK=0
FAILED=()
START_ALL=$(date +%s)
i=0
for src in "${SOURCES[@]}"; do
  i=$((i + 1))
  tool="$(tool_name "$src")"
  flags=("${OPT_FLAGS[@]}")
  if grep -q '^[[:space:]]*@main' "$src"; then
    flags+=(-parse-as-library)
  fi
  printf "[%2d/%2d] %-24s " "$i" "$TOTAL" "$tool"
  t0=$(date +%s)
  # Compile to a temp path first so a failed build never clobbers a working binary.
  tmp_out="$LOG_DIR/$tool"
  if swiftc "${flags[@]}" "$src" -o "$tmp_out" >"$LOG_DIR/$tool.log" 2>&1; then
    mv -f "$tmp_out" "$OUT_DIR/$tool"
    chmod +x "$OUT_DIR/$tool"
    printf "%sOK%s   (%ds)\n" "$GREEN" "$RESET" "$(( $(date +%s) - t0 ))"
    OK=$((OK + 1))
  else
    printf "%sFAIL%s\n" "$RED" "$RESET"
    sed 's/^/        /' "$LOG_DIR/$tool.log" | head -20
    FAILED+=("$tool")
  fi
done

echo "----------------------------------------------------------------"
echo "Built $OK/$TOTAL in $(( $(date +%s) - START_ALL ))s"
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "${YELLOW}Failed:${RESET} ${FAILED[*]}"
  exit 1
fi
