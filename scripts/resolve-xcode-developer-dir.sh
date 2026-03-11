#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/.xcode-version"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "[xcode-resolver] .xcode-version 파일이 없습니다: $VERSION_FILE" >&2
  exit 1
fi

EXPECTED_VERSION="$(tr -d '[:space:]' <"$VERSION_FILE")"

if [[ -z "$EXPECTED_VERSION" ]]; then
  echo "[xcode-resolver] .xcode-version 값이 비어 있습니다." >&2
  exit 1
fi

normalize_developer_dir() {
  local candidate="$1"

  if [[ "$candidate" == *.app ]]; then
    printf '%s/Contents/Developer\n' "$candidate"
    return
  fi

  printf '%s\n' "$candidate"
}

xcode_version_output() {
  local developer_dir="$1"

  if [[ ! -x "$developer_dir/usr/bin/xcodebuild" ]]; then
    return 1
  fi

  "$developer_dir/usr/bin/xcodebuild" -version 2>/dev/null
}

matches_expected_version() {
  local version_output="$1"
  local first_line

  first_line="$(printf '%s\n' "$version_output" | head -n 1)"
  [[ "$first_line" == "Xcode $EXPECTED_VERSION"* ]]
}

describe_candidate() {
  local raw_candidate="$1"
  local label="$2"
  local developer_dir
  local version_output
  local first_line

  developer_dir="$(normalize_developer_dir "$raw_candidate")"
  if [[ ! -d "$developer_dir" ]]; then
    printf '  - %s: 없음 (%s)\n' "$label" "$developer_dir" >&2
    return
  fi

  if ! version_output="$(xcode_version_output "$developer_dir")"; then
    printf '  - %s: xcodebuild 없음 (%s)\n' "$label" "$developer_dir" >&2
    return
  fi

  first_line="$(printf '%s\n' "$version_output" | head -n 1)"
  printf '  - %s: %s (%s)\n' "$label" "$first_line" "$developer_dir" >&2
}

fail_with_context() {
  local reason="$1"

  echo "[xcode-resolver] 저장소 기준 Xcode ${EXPECTED_VERSION}을 찾지 못했습니다." >&2
  echo "[xcode-resolver] 원인: $reason" >&2
  echo "[xcode-resolver] 확인한 후보:" >&2

  if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    describe_candidate "$DEVELOPER_DIR" "DEVELOPER_DIR"
  fi

  if [[ -n "${XCODE_SELECT_PATH:-}" ]]; then
    describe_candidate "$XCODE_SELECT_PATH" "xcode-select -p"
  fi

  for candidate in "${DISCOVERY_CANDIDATES[@]}"; do
    describe_candidate "$candidate" "$candidate"
  done

  echo "[xcode-resolver] 해결 방법:" >&2
  echo "  1. Xcode ${EXPECTED_VERSION} 설치 여부를 확인하세요." >&2
  echo "  2. 현재 셸에서는 실제 설치 경로로 DEVELOPER_DIR를 지정하세요. 예: /Applications/Xcode_${EXPECTED_VERSION}.app/Contents/Developer 또는 /Applications/Xcode.app/Contents/Developer" >&2
  echo "  3. 저장소 스크립트 실행 전 ./scripts/resolve-xcode-developer-dir.sh 로 경로를 검증하세요." >&2
  exit 1
}

DISCOVERY_CANDIDATES=(
  "/Applications/Xcode_${EXPECTED_VERSION}.app"
)

if [[ "$EXPECTED_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
  DISCOVERY_CANDIDATES+=("/Applications/Xcode_${EXPECTED_VERSION}.0.app")
fi

DISCOVERY_CANDIDATES+=("/Applications/Xcode.app")

if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  NORMALIZED_DEVELOPER_DIR="$(normalize_developer_dir "$DEVELOPER_DIR")"
  if ! VERSION_OUTPUT="$(xcode_version_output "$NORMALIZED_DEVELOPER_DIR")"; then
    fail_with_context "DEVELOPER_DIR가 유효한 Xcode 개발자 디렉터리를 가리키지 않습니다."
  fi

  if ! matches_expected_version "$VERSION_OUTPUT"; then
    fail_with_context "설정된 DEVELOPER_DIR의 Xcode 버전이 기대값과 다릅니다."
  fi

  printf '%s\n' "$NORMALIZED_DEVELOPER_DIR"
  exit 0
fi

XCODE_SELECT_PATH="$(xcode-select -p 2>/dev/null || true)"
if [[ -n "$XCODE_SELECT_PATH" ]]; then
  NORMALIZED_XCODE_SELECT_PATH="$(normalize_developer_dir "$XCODE_SELECT_PATH")"
  if VERSION_OUTPUT="$(xcode_version_output "$NORMALIZED_XCODE_SELECT_PATH")"; then
    if matches_expected_version "$VERSION_OUTPUT"; then
      printf '%s\n' "$NORMALIZED_XCODE_SELECT_PATH"
      exit 0
    fi
  fi
fi

# Fall back to explicit /Applications candidates when the active developer
# directory is missing or does not match the pinned version.
for candidate in "${DISCOVERY_CANDIDATES[@]}"; do
  normalized_candidate="$(normalize_developer_dir "$candidate")"
  if ! VERSION_OUTPUT="$(xcode_version_output "$normalized_candidate")"; then
    continue
  fi

  if matches_expected_version "$VERSION_OUTPUT"; then
    printf '%s\n' "$normalized_candidate"
    exit 0
  fi
done

fail_with_context "설치된 Xcode 중 저장소 기준 버전과 일치하는 후보가 없습니다."
