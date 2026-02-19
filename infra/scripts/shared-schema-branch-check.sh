#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${INFRA_DIR}/.." && pwd)"
SHARED_DIR="${REPO_ROOT}/shared-schema"
TARGET_REF="${SHARED_SCHEMA_CANONICAL_REF:-origin/main}"
REMOTE_BRANCH="${TARGET_REF#origin/}"

if [[ ! -d "${SHARED_DIR}" ]]; then
  echo "[shared-branch-check] missing shared-schema submodule." >&2
  echo "[shared-branch-check] run: git submodule update --init --recursive" >&2
  exit 1
fi

if ! git -C "${SHARED_DIR}" fetch origin "${REMOTE_BRANCH}" --quiet; then
  echo "[shared-branch-check] failed to fetch origin/${REMOTE_BRANCH}" >&2
  exit 1
fi

if ! git -C "${SHARED_DIR}" rev-parse --verify "${TARGET_REF}" >/dev/null 2>&1; then
  echo "[shared-branch-check] ref not found: ${TARGET_REF}" >&2
  exit 1
fi

HEAD_SHA="$(git -C "${SHARED_DIR}" rev-parse HEAD)"
BRANCH_NAME="$(git -C "${SHARED_DIR}" symbolic-ref --short -q HEAD || echo detached-head)"

if ! git -C "${SHARED_DIR}" merge-base --is-ancestor "${TARGET_REF}" HEAD; then
  echo "[shared-branch-check] shared-schema HEAD ${HEAD_SHA} does not include ${TARGET_REF}" >&2
  echo "[shared-branch-check] rebase/merge ${TARGET_REF} into your shared-schema branch first." >&2
  exit 1
fi

echo "[shared-branch-check] passed: shared-schema HEAD ${HEAD_SHA} (branch: ${BRANCH_NAME}) is on ${TARGET_REF}"
