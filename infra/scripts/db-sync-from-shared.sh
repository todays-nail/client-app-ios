#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-sync}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${INFRA_DIR}/.." && pwd)"
DST_DIR="${INFRA_DIR}/supabase/migrations"
SHARED_SCHEMA_REPO_URL="${SHARED_SCHEMA_REPO_URL:-https://github.com/todays-nail/shared-schema.git}"
SHARED_SCHEMA_REF="${SHARED_SCHEMA_REF:-1c1a08472bd9f0ef0f77e730ec7557bd0ac4a829}"
TMP_DIR="$(mktemp -d)"
SHARED_DIR="${TMP_DIR}/shared-schema"
SRC_DIR="${SHARED_DIR}/migrations"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

fetch_shared_schema() {
  mkdir -p "${SHARED_DIR}"
  git -C "${SHARED_DIR}" init -q
  git -C "${SHARED_DIR}" remote add origin "${SHARED_SCHEMA_REPO_URL}"

  if ! git -C "${SHARED_DIR}" fetch --depth 1 origin "${SHARED_SCHEMA_REF}" >/dev/null 2>&1; then
    echo "[db-sync] failed to fetch shared schema" >&2
    echo "[db-sync] repo: ${SHARED_SCHEMA_REPO_URL}" >&2
    echo "[db-sync] ref: ${SHARED_SCHEMA_REF}" >&2
    exit 1
  fi

  git -C "${SHARED_DIR}" checkout --detach -q FETCH_HEAD
}

fetch_shared_schema

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "[db-sync] source not found after fetch: ${SRC_DIR}" >&2
  exit 1
fi

mkdir -p "${DST_DIR}"

source_manifest() {
  (
    cd "${SRC_DIR}"
    find . -maxdepth 1 -type f -name '*.sql' -print | sort | while read -r p; do
      shasum -a 256 "${p}"
    done
  )
}

target_manifest() {
  (
    cd "${DST_DIR}"
    find . -maxdepth 1 -type f -name '*.sql' -print | sort | while read -r p; do
      shasum -a 256 "${p}"
    done
  )
}

if [[ "${MODE}" == "--check" ]]; then
  src_file="$(mktemp)"
  dst_file="$(mktemp)"
  trap 'rm -f "${src_file}" "${dst_file}"' EXIT

  source_manifest > "${src_file}"
  target_manifest > "${dst_file}"

  if diff -u "${src_file}" "${dst_file}" >/dev/null; then
    echo "[db-sync] check passed: infra/supabase/migrations is in sync with shared-schema/migrations (${SHARED_SCHEMA_REF})"
    exit 0
  fi

  echo "[db-sync] check failed: migration directories differ" >&2
  diff -u "${src_file}" "${dst_file}" || true
  exit 1
fi

rsync -a --delete --include='*.sql' --exclude='*' "${SRC_DIR}/" "${DST_DIR}/"
echo "[db-sync] synced shared-schema/migrations (${SHARED_SCHEMA_REF}) -> infra/supabase/migrations"
