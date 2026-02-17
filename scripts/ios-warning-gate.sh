#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/NailClient/NailClient.xcodeproj"
SCHEME="NailClient"
BASELINE_PATH="$ROOT_DIR/NailClient/warning-baseline.txt"
DEVELOPER_DIR_VALUE="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

UPDATE_BASELINE=0
if [[ "${1:-}" == "--update-baseline" ]]; then
  UPDATE_BASELINE=1
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ios-warning-gate.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

RELEASE_LOG="$TMP_DIR/release.log"
DEBUG_LOG="$TMP_DIR/debug.log"
ALL_WARNINGS="$TMP_DIR/all_warnings.txt"
APP_WARNINGS="$TMP_DIR/app_warnings.txt"
TOOL_WARNINGS="$TMP_DIR/tool_warnings.txt"
UNKNOWN_TOOL_WARNINGS="$TMP_DIR/unknown_tool_warnings.txt"

run_release_build() {
  echo "[warning-gate] Release clean build..."
  DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" \
    xcodebuild \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME" \
      -configuration Release \
      -destination 'generic/platform=iOS' \
      CODE_SIGNING_ALLOWED=NO \
      clean build >"$RELEASE_LOG" 2>&1 &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    sleep 20
    if kill -0 "$pid" 2>/dev/null; then
      echo "[warning-gate] Release clean build 진행 중..."
    fi
  done
  if ! wait "$pid"; then
    echo "[warning-gate] Release clean build 실패. 최근 로그:"
    tail -n 120 "$RELEASE_LOG" || true
    return 1
  fi
}

run_debug_build() {
  echo "[warning-gate] Debug simulator build..."
  DEVELOPER_DIR="$DEVELOPER_DIR_VALUE" \
    xcodebuild \
      -project "$PROJECT_PATH" \
      -scheme "$SCHEME" \
      -configuration Debug \
      -sdk iphonesimulator \
      build >"$DEBUG_LOG" 2>&1 &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    sleep 20
    if kill -0 "$pid" 2>/dev/null; then
      echo "[warning-gate] Debug simulator build 진행 중..."
    fi
  done
  if ! wait "$pid"; then
    echo "[warning-gate] Debug simulator build 실패. 최근 로그:"
    tail -n 120 "$DEBUG_LOG" || true
    return 1
  fi
}

collect_warnings() {
  cat "$RELEASE_LOG" "$DEBUG_LOG" \
    | grep "warning:" \
    | sed -E "s|$ROOT_DIR/||g" \
    | sed -E 's|^(NailClient/NailClient/[^:]+):[0-9]+:[0-9]+: warning: |\1: warning: |' \
    | sed -E 's|[[:space:]]+$||' \
    | sort -u >"$ALL_WARNINGS" || true

  grep -E '^NailClient/NailClient/[^:]+: warning:' "$ALL_WARNINGS" | sort -u >"$APP_WARNINGS" || true
  grep -Ev '^NailClient/NailClient/[^:]+: warning:' "$ALL_WARNINGS" | sort -u >"$TOOL_WARNINGS" || true
}

is_allowed_tool_warning() {
  local line="$1"
  if [[ "$line" == *"Metadata extraction skipped. No AppIntents.framework dependency found."* ]]; then
    return 0
  fi
  if [[ "$line" == *"'UIRequiresFullScreen' has been deprecated"* ]]; then
    return 0
  fi
  return 1
}

validate_tool_warnings() {
  : >"$UNKNOWN_TOOL_WARNINGS"

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if ! is_allowed_tool_warning "$line"; then
      echo "$line" >>"$UNKNOWN_TOOL_WARNINGS"
    fi
  done <"$TOOL_WARNINGS"

  if [[ -s "$UNKNOWN_TOOL_WARNINGS" ]]; then
    echo "[warning-gate] 허용되지 않은 도구성 경고가 있습니다:"
    cat "$UNKNOWN_TOOL_WARNINGS"
    return 1
  fi
}

validate_app_warning_baseline() {
  if [[ "$UPDATE_BASELINE" -eq 1 ]]; then
    cp "$APP_WARNINGS" "$BASELINE_PATH"
    echo "[warning-gate] baseline 업데이트 완료: $BASELINE_PATH"
    return 0
  fi

  if [[ ! -f "$BASELINE_PATH" ]]; then
    echo "[warning-gate] baseline 파일이 없습니다: $BASELINE_PATH"
    echo "[warning-gate] 먼저 'bash scripts/ios-warning-gate.sh --update-baseline'를 실행하세요."
    return 1
  fi

  local baseline_sorted="$TMP_DIR/baseline_sorted.txt"
  local new_warnings="$TMP_DIR/new_app_warnings.txt"
  local resolved_warnings="$TMP_DIR/resolved_app_warnings.txt"

  sort -u "$BASELINE_PATH" >"$baseline_sorted"
  comm -13 "$baseline_sorted" "$APP_WARNINGS" >"$new_warnings" || true
  comm -23 "$baseline_sorted" "$APP_WARNINGS" >"$resolved_warnings" || true

  if [[ -s "$new_warnings" ]]; then
    echo "[warning-gate] 신규 앱 소스 경고가 있습니다:"
    cat "$new_warnings"
    return 1
  fi

  if [[ -s "$resolved_warnings" ]]; then
    echo "[warning-gate] 참고: baseline 대비 사라진 경고가 있습니다."
    cat "$resolved_warnings"
    echo "[warning-gate] 필요하면 '--update-baseline'로 baseline을 갱신하세요."
  fi
}

run_release_build
run_debug_build
collect_warnings
validate_tool_warnings
validate_app_warning_baseline

echo "[warning-gate] 통과"
echo "[warning-gate] 앱 경고 수: $(wc -l <"$APP_WARNINGS" | tr -d ' ')"
echo "[warning-gate] 도구 경고 수(허용): $(wc -l <"$TOOL_WARNINGS" | tr -d ' ')"
