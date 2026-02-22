#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/NailClient/NailClient.xcodeproj"
SCHEME="NailClient"
DEVELOPER_DIR_DEFAULT="/Applications/Xcode.app/Contents/Developer"
DESTINATION="platform=iOS Simulator,name=iPhone 17,OS=26.0"
DURATION_FORMAT=%Y%m%d_%H%M%S
SIMULATOR_RUNTIME="26.0"
CLEANUP=0
LOCK_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cleanup)
      CLEANUP=1
      shift
      ;;
    --help|-h)
      echo "Usage: $(basename "$0") [--cleanup] [--help]"
      echo "  --cleanup   Kill orphaned IBAgent/iBtoold/SWBBuildService processes before build"
      echo "  --help      Show this message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 2
      ;;
  esac
done

DEVELOPER_DIR="${DEVELOPER_DIR:-$DEVELOPER_DIR_DEFAULT}"
export DEVELOPER_DIR

validate_developer_dir() {
  if [[ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
    echo "xcodebuild를 찾을 수 없습니다. DEVELOPER_DIR를 확인하세요: $DEVELOPER_DIR"
    exit 1
  fi
  if [[ ! -x "$DEVELOPER_DIR/usr/bin/ibtool" ]]; then
    echo "ibtool을 찾을 수 없습니다. DEVELOPER_DIR를 확인하세요: $DEVELOPER_DIR"
    exit 1
  fi
}

cleanup_tool_processes() {
  if [[ "$CLEANUP" -ne 1 ]]; then
    return
  fi

  local targets=(ibtoold IBAgent-iOS SWBBuildService)
  for name in "${targets[@]}"; do
    for pid in $(pgrep -x "$name" || true); do
      # Keep running xcode tools spawned with valid parent; remove only orphaned helpers
      local ppid
      ppid=$(ps -o ppid= -p "$pid" | tr -d ' ' || echo "")
      local cmd
      cmd=$(ps -o command= -p "$pid" | tr -d '\n' || true)
      echo "[cleanup] stale $name pid=$pid ppid=$ppid cmd=$cmd"
      if [[ "$ppid" == "1" ]]; then
        kill -9 "$pid" || true
      fi
    done
  done
}

ensure_singleton() {
  local lock_dir="$ROOT_DIR/.tmp/.nailclient-stable-build.lock"
  mkdir -p "$ROOT_DIR/.tmp"
  if [[ -e "$lock_dir" && ! -d "$lock_dir" ]]; then
    rm -f "$lock_dir"
  fi
  if mkdir "$lock_dir" 2>/dev/null; then
    LOCK_DIR="$lock_dir"
    trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
    return
  fi

  echo "동일 작업이 이미 실행 중입니다. 병렬 빌드를 피하기 위해 종료 후 재시도하세요."
  exit 1
}

check_running_builds() {
  local pids
  pids=$(pgrep -x xcodebuild || true)
  if [[ -n "$pids" ]]; then
    echo "기존 xcodebuild 프로세스가 실행 중입니다:"
    ps -o pid=,ppid=,command= -p $pids || true
    echo "동시 빌드로 인한 락 충돌 위험이 있으므로 먼저 종료 후 재시도하세요."
    exit 1
  fi
}

run_ibtool_smoke() {
  local launch_storyboard="$ROOT_DIR/NailClient/NailClient/LaunchScreen.storyboard"
  local out_dir="/tmp/NailClient-LaunchScreen-ibtool-$(date +$DURATION_FORMAT)"
  local log="${out_dir}.log"

  echo "[ibtool] LaunchScreen compile smoke test"
  if "$DEVELOPER_DIR/usr/bin/ibtool" --errors --warnings --notices --output-format human-readable-text --compile "$out_dir" "$launch_storyboard" > "$log" 2>&1; then
    echo "[ibtool] OK (log=$log)"
  else
    echo "[ibtool] FAILED (log=$log)"
    tail -n 80 "$log" || true
    return 1
  fi
}

run_build() {
  local ts now_dir rb log_file rc
  ts="$(date +$DURATION_FORMAT)"
  now_dir="/tmp/NailClient-DD-stable-${ts}"
  rb="/tmp/nailclient-stable-${ts}.xcresult"
  log_file="/tmp/nailclient-stable-${ts}.log"

  echo "[build] using DEVELOPER_DIR=$DEVELOPER_DIR"
  echo "[build] derivedData=$now_dir"
  echo "[build] resultBundle=$rb"
  if "$DEVELOPER_DIR/usr/bin/xcodebuild" \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination "$DESTINATION" \
    -derivedDataPath "$now_dir" \
    -resultBundlePath "$rb" \
    build > "$log_file" 2>&1; then
    rc=0
  else
    rc=$?
  fi

  echo "[build] rc=${rc}, log=${log_file}, elapsed maybe check manually"
  if [[ "$rc" -ne 0 ]]; then
    echo "[build] 실패 상세:"
    tail -n 120 "$log_file" || true
    return "$rc"
  fi

  echo "[build] 완료: $(tail -n 1 "$log_file")"
  tail -n 20 "$log_file" || true
}

ensure_singleton
validate_developer_dir
cleanup_tool_processes
check_running_builds
"$DEVELOPER_DIR/usr/bin/xcodebuild" -version
check_running_builds
run_ibtool_smoke
run_build
