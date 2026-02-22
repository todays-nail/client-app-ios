#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${INFRA_DIR}/.env"

cd "${INFRA_DIR}"

"${SCRIPT_DIR}/migrations-lint.sh"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

DB_URL="${SUPABASE_DB_URL_SHARED_STAGING:-${SUPABASE_DB_URL_IOS_DEV:-}}"

if [[ -z "${DB_URL}" ]]; then
  echo "Missing env: SUPABASE_DB_URL_SHARED_STAGING" >&2
  exit 1
fi

if [[ -n "${SUPABASE_DB_URL_SHARED_PROD:-}" && "${DB_URL}" == "${SUPABASE_DB_URL_SHARED_PROD}" ]]; then
  echo "Push target must not be shared-prod." >&2
  exit 1
fi

supabase db push --db-url "${DB_URL}"
