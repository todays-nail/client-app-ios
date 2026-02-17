#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${INFRA_DIR}"

"${SCRIPT_DIR}/migrations-lint.sh"
"${SCRIPT_DIR}/db-sync-from-shared.sh" --check

DB_URL="${SUPABASE_DB_URL_IOS_DEV:-}"

run_with_fallback() {
  local label="$1"
  local linked_cmd="$2"
  local dburl_cmd="$3"

  if eval "${linked_cmd}"; then
    return 0
  fi

  if [[ -z "${DB_URL}" ]]; then
    echo "[db-check] ${label}: --linked 실패, SUPABASE_DB_URL_IOS_DEV 미설정으로 fallback 불가" >&2
    exit 1
  fi

  echo "[db-check] ${label}: --linked 실패, --db-url fallback 실행"
  eval "${dburl_cmd}"
}

run_with_fallback \
  "supabase migration list" \
  "supabase migration list" \
  "supabase migration list --db-url '${DB_URL}'"

run_with_fallback \
  "supabase db push --dry-run" \
  "supabase db push --dry-run" \
  "supabase db push --dry-run --db-url '${DB_URL}'"

run_with_fallback \
  "supabase db diff" \
  "supabase db diff --linked" \
  "supabase db diff --db-url '${DB_URL}'"

echo "[db-check] completed"
