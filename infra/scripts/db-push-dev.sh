#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${INFRA_DIR}"

"${SCRIPT_DIR}/migrations-lint.sh"

if [[ -z "${SUPABASE_DB_URL_IOS_DEV:-}" ]]; then
  echo "Missing env: SUPABASE_DB_URL_IOS_DEV" >&2
  exit 1
fi

if [[ -n "${SUPABASE_DB_URL_SHARED_STAGING:-}" && "${SUPABASE_DB_URL_IOS_DEV}" == "${SUPABASE_DB_URL_SHARED_STAGING}" ]]; then
  echo "SUPABASE_DB_URL_IOS_DEV must not point to shared-staging." >&2
  exit 1
fi

if [[ -n "${SUPABASE_DB_URL_SHARED_PROD:-}" && "${SUPABASE_DB_URL_IOS_DEV}" == "${SUPABASE_DB_URL_SHARED_PROD}" ]]; then
  echo "SUPABASE_DB_URL_IOS_DEV must not point to shared-prod." >&2
  exit 1
fi

if [[ "${SUPABASE_DB_URL_IOS_DEV}" == *"twahqxjhyocyqrmtjbdf"* ]]; then
  echo "SUPABASE_DB_URL_IOS_DEV points to shared-staging(ref: twahqxjhyocyqrmtjbdf). direct push is forbidden." >&2
  exit 1
fi

supabase db push --db-url "${SUPABASE_DB_URL_IOS_DEV}" --yes
