#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${INFRA_DIR}/.env"

cd "${INFRA_DIR}"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

"${SCRIPT_DIR}/migrations-lint.sh"
"${SCRIPT_DIR}/db-sync-from-shared.sh" --check

DB_URL="${SUPABASE_DB_URL_SHARED_STAGING:-${SUPABASE_DB_URL_IOS_DEV:-}}"
PROJECT_ID="$(awk -F '\"' '/^project_id/ {print $2; exit}' "${INFRA_DIR}/supabase/config.toml" 2>/dev/null || true)"

run_with_fallback() {
  local label="$1"
  local linked_cmd="$2"
  local dburl_cmd="$3"
  local allow_restart_local_db="false"

  if [[ "${label}" == "supabase db diff" ]]; then
    allow_restart_local_db="true"
  fi

  if eval "${linked_cmd}"; then
    return 0
  fi

  if [[ "${allow_restart_local_db}" == "true" && -n "${PROJECT_ID:-}" ]]; then
    echo "[db-check] ${label}: local shadow DB 포트 충돌 가능성으로 local 프로젝트를 한번 정리 후 재시도"
    supabase stop --project-id "${PROJECT_ID}" >/dev/null 2>&1 || true
    if eval "${linked_cmd}"; then
      return 0
    fi
  fi

  if [[ -z "${DB_URL}" ]]; then
    echo "[db-check] ${label}: --linked 실패, SUPABASE_DB_URL_SHARED_STAGING/IOS_DEV 미설정으로 fallback 불가" >&2
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

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  run_with_fallback \
    "supabase db diff" \
    "supabase db diff --linked" \
    "supabase db diff --db-url '${DB_URL}'"
else
  echo "[db-check] docker unavailable: skip supabase db diff"
fi

echo "[db-check] completed"
