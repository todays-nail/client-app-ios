#!/usr/bin/env bash
set -euo pipefail

SHARED_SCHEMA_REPO_URL="${SHARED_SCHEMA_REPO_URL:-https://github.com/todays-nail/shared-schema.git}"
SHARED_SCHEMA_REF="${SHARED_SCHEMA_REF:-1c1a08472bd9f0ef0f77e730ec7557bd0ac4a829}"
TMP_DIR="$(mktemp -d)"
SHARED_DIR="${TMP_DIR}/shared-schema"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${SHARED_DIR}"
git -C "${SHARED_DIR}" init -q
git -C "${SHARED_DIR}" remote add origin "${SHARED_SCHEMA_REPO_URL}"

if ! git -C "${SHARED_DIR}" fetch --depth 1 origin "${SHARED_SCHEMA_REF}" >/dev/null 2>&1; then
  echo "[shared-branch-check] failed to fetch shared schema" >&2
  echo "[shared-branch-check] repo: ${SHARED_SCHEMA_REPO_URL}" >&2
  echo "[shared-branch-check] ref: ${SHARED_SCHEMA_REF}" >&2
  exit 1
fi

FETCHED_SHA="$(git -C "${SHARED_DIR}" rev-parse FETCH_HEAD)"
echo "[shared-branch-check] passed: shared-schema ref ${SHARED_SCHEMA_REF} resolved to ${FETCHED_SHA}"
