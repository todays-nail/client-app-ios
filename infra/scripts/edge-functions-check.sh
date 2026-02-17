#!/usr/bin/env bash

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FUNCTIONS_DIR="$ROOT_DIR/supabase/functions"

if ! command -v deno >/dev/null 2>&1; then
  echo "ERROR: deno is not installed. Install with: brew install deno"
  exit 1
fi

ENTRYPOINTS=()
while IFS= read -r file; do
  ENTRYPOINTS+=("$file")
done < <(find "$FUNCTIONS_DIR" -mindepth 2 -maxdepth 2 -name "index.ts" | sort)

if [[ ${#ENTRYPOINTS[@]} -eq 0 ]]; then
  echo "No Supabase Edge Function entrypoints found."
  exit 0
fi

echo "Checking ${#ENTRYPOINTS[@]} edge function(s) with deno check..."

FAILURES=0
FAILED_FILES=()

for file in "${ENTRYPOINTS[@]}"; do
  rel_path="${file#"$ROOT_DIR"/}"
  echo ""
  echo "==> $rel_path"
  if deno check "$file"; then
    continue
  fi

  FAILURES=$((FAILURES + 1))
  FAILED_FILES+=("$rel_path")
done

if [[ $FAILURES -gt 0 ]]; then
  echo ""
  echo "Failed checks: $FAILURES"
  for path in "${FAILED_FILES[@]}"; do
    echo " - $path"
  done
  exit 1
fi

echo ""
echo "All edge function checks passed."
