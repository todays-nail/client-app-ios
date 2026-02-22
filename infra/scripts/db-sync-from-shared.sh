#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-sync}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${INFRA_DIR}/.." && pwd)"
SRC_DIR="${REPO_ROOT}/shared-schema/migrations"
DST_DIR="${INFRA_DIR}/supabase/migrations"

if [[ ! -d "${SRC_DIR}" ]]; then
  echo "[db-sync] source not found: ${SRC_DIR}" >&2
  echo "[db-sync] shared-schema submodule을 먼저 초기화하세요." >&2
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
    echo "[db-sync] check passed: infra/supabase/migrations is in sync with shared-schema/migrations"
    exit 0
  fi

  echo "[db-sync] check failed: migration directories differ" >&2
  diff -u "${src_file}" "${dst_file}" || true
  exit 1
fi

rsync -a --delete --include='*.sql' --exclude='*' "${SRC_DIR}/" "${DST_DIR}/"
echo "[db-sync] synced shared-schema/migrations -> infra/supabase/migrations"
