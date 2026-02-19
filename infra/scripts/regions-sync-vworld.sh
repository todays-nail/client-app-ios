#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

print_usage() {
  cat <<USAGE
Usage:
  $(basename "$0") [--db-url <url>] [--source-version <YYYY-MM>] [--sigungu-json <path>] [--emd-json <path>] [--dry-run]

Options:
  --db-url         PostgreSQL URL (default: SUPABASE_DB_URL_SHARED_STAGING env)
  --source-version 데이터 버전 라벨 (default: 반기 기준 자동 계산, 예: 2026-01 / 2026-07)
  --sigungu-json   ADSIGG GeoJSON 파일 경로 (없으면 VWorld API 호출)
  --emd-json       ADEMD GeoJSON 파일 경로 (없으면 VWorld API 호출)
  --dry-run        DB 반영 없이 수집/매칭 통계만 출력

Required env for remote fetch:
  VWORLD_API_KEY
USAGE
}

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[regions-sync] missing command: $cmd" >&2
    exit 1
  fi
}

normalize_version() {
  local now_ym year month
  now_ym="$(date +%Y-%m)"
  year="${now_ym%-*}"
  month="${now_ym#*-}"

  if ((10#$month >= 7)); then
    echo "${year}-07"
  else
    echo "${year}-01"
  fi
}

extract_features_ndjson() {
  local input="$1"
  local output="$2"

  jq -c '
    ..
    | objects
    | select(has("features") and (.features | type == "array"))
    | .features[]
  ' "$input" >> "$output"
}

fetch_vworld_layer() {
  local data_name="$1"
  local output_geojson="$2"
  local api_key="$3"

  local page size tmp_file ndjson count
  page=1
  size=1000
  ndjson="$(mktemp)"

  while true; do
    tmp_file="$(mktemp)"
    local url="https://api.vworld.kr/req/data?service=data&request=GetFeature&version=2.0&format=json&size=${size}&page=${page}&data=${data_name}&key=${api_key}"

    if ! curl -fsSL "$url" -o "$tmp_file"; then
      echo "[regions-sync] vworld fetch failed: layer=${data_name} page=${page}" >&2
      rm -f "$tmp_file" "$ndjson"
      exit 1
    fi

    extract_features_ndjson "$tmp_file" "$ndjson"
    count="$(jq -r '
      [
        ..
        | objects
        | select(has("features") and (.features | type == "array"))
        | .features[]
      ]
      | length
    ' "$tmp_file")"
    rm -f "$tmp_file"

    if [[ "$count" == "0" ]]; then
      break
    fi

    if (( count < size )); then
      break
    fi

    page=$((page + 1))
  done

  jq -s '{ type: "FeatureCollection", features: . }' "$ndjson" > "$output_geojson"
  rm -f "$ndjson"
}

create_sigungu_tsv() {
  local input_geojson="$1"
  local output_tsv="$2"

  jq -r '
    .features[]?
    | . as $f
    | ($f.properties // {}) as $p
    | {
        sido: ($p.ctp_kor_nm // $p.CTP_KOR_NM // $p.ctprvn_nm // $p.CTPRVN_NM // ""),
        sigungu: ($p.sig_kor_nm // $p.SIG_KOR_NM // $p.sigungu_nm // $p.SIGUNGU_NM // ""),
        geometry: ($f.geometry // null),
        bbox: ($f.bbox // null)
      }
    | select(.sido != "" and .sigungu != "" and .geometry != null)
    | .center = (
        if (.bbox | type) == "array" and (.bbox | length) == 4
        then [((.bbox[0] + .bbox[2]) / 2), ((.bbox[1] + .bbox[3]) / 2)]
        else null
        end
      )
    | [
        .sido,
        .sigungu,
        (.geometry | @json),
        (.bbox | @json),
        (.center | @json)
      ]
    | @tsv
  ' "$input_geojson" > "$output_tsv"
}

create_emd_tsv() {
  local input_geojson="$1"
  local output_tsv="$2"

  jq -r '
    .features[]?
    | . as $f
    | ($f.properties // {}) as $p
    | {
        sido: ($p.ctp_kor_nm // $p.CTP_KOR_NM // $p.ctprvn_nm // $p.CTPRVN_NM // ""),
        sigungu: ($p.sig_kor_nm // $p.SIG_KOR_NM // $p.sigungu_nm // $p.SIGUNGU_NM // ""),
        emd: ($p.emd_kor_nm // $p.EMD_KOR_NM // $p.emd_nm // $p.EMD_NM // ""),
        geometry: ($f.geometry // null),
        bbox: ($f.bbox // null)
      }
    | select(.sido != "" and .sigungu != "" and .emd != "" and .geometry != null)
    | .center = (
        if (.bbox | type) == "array" and (.bbox | length) == 4
        then [((.bbox[0] + .bbox[2]) / 2), ((.bbox[1] + .bbox[3]) / 2)]
        else null
        end
      )
    | [
        .sido,
        .sigungu,
        .emd,
        (.geometry | @json),
        (.bbox | @json),
        (.center | @json)
      ]
    | @tsv
  ' "$input_geojson" > "$output_tsv"
}

DB_URL="${SUPABASE_DB_URL_SHARED_STAGING:-}"
SOURCE_VERSION="$(normalize_version)"
SIGUNGU_JSON=""
EMD_JSON=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-url)
      DB_URL="${2:-}"
      shift 2
      ;;
    --source-version)
      SOURCE_VERSION="${2:-}"
      shift 2
      ;;
    --sigungu-json)
      SIGUNGU_JSON="${2:-}"
      shift 2
      ;;
    --emd-json)
      EMD_JSON="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "[regions-sync] unknown argument: $1" >&2
      print_usage
      exit 1
      ;;
  esac
done

require_cmd jq
require_cmd curl
require_cmd psql

if [[ -z "$DB_URL" ]]; then
  echo "[regions-sync] --db-url or SUPABASE_DB_URL_SHARED_STAGING is required" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -z "$SIGUNGU_JSON" ]]; then
  if [[ -z "${VWORLD_API_KEY:-}" ]]; then
    echo "[regions-sync] VWORLD_API_KEY is required when --sigungu-json is omitted" >&2
    exit 1
  fi
  SIGUNGU_JSON="$TMP_DIR/adsigg.geojson"
  echo "[regions-sync] fetching ADSIGG from VWorld..."
  fetch_vworld_layer "LT_C_ADSIGG_INFO" "$SIGUNGU_JSON" "$VWORLD_API_KEY"
fi

if [[ -z "$EMD_JSON" ]]; then
  if [[ -z "${VWORLD_API_KEY:-}" ]]; then
    echo "[regions-sync] VWORLD_API_KEY is required when --emd-json is omitted" >&2
    exit 1
  fi
  EMD_JSON="$TMP_DIR/ademd.geojson"
  echo "[regions-sync] fetching ADEMD from VWorld..."
  fetch_vworld_layer "LT_C_ADEMD_INFO" "$EMD_JSON" "$VWORLD_API_KEY"
fi

SIGUNGU_TSV="$TMP_DIR/sigungu.tsv"
EMD_TSV="$TMP_DIR/emd.tsv"

create_sigungu_tsv "$SIGUNGU_JSON" "$SIGUNGU_TSV"
create_emd_tsv "$EMD_JSON" "$EMD_TSV"

echo "[regions-sync] prepared rows:"
echo "  - sigungu: $(wc -l < "$SIGUNGU_TSV" | tr -d ' ')"
echo "  - emd:     $(wc -l < "$EMD_TSV" | tr -d ' ')"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[regions-sync] dry-run enabled. DB updates skipped."
  exit 0
fi

SIGUNGU_ESCAPED="${SIGUNGU_TSV//\//\/}"
EMD_ESCAPED="${EMD_TSV//\//\/}"

psql "$DB_URL" -v ON_ERROR_STOP=1 -v source_version="$SOURCE_VERSION" <<SQL
begin;

create temporary table tmp_vworld_sigungu (
  sido text not null,
  sigungu text not null,
  geometry text not null,
  bbox text,
  center text
) on commit drop;

create temporary table tmp_vworld_emd (
  sido text not null,
  sigungu text not null,
  emd text not null,
  geometry text not null,
  bbox text,
  center text
) on commit drop;

\copy tmp_vworld_sigungu (sido, sigungu, geometry, bbox, center) from '${SIGUNGU_ESCAPED}' with (format csv, delimiter E'\t', quote E'\b')
\copy tmp_vworld_emd (sido, sigungu, emd, geometry, bbox, center) from '${EMD_ESCAPED}' with (format csv, delimiter E'\t', quote E'\b')

-- 경기도만 level3(구) 자동 생성. 이미 있으면 skip.
insert into public.regions (id, name, parent_id, level)
select
  (
    substr(md5(city.id::text || ':' || emd.emd), 1, 8) || '-' ||
    substr(md5(city.id::text || ':' || emd.emd), 9, 4) || '-4' ||
    substr(md5(city.id::text || ':' || emd.emd), 14, 3) || '-a' ||
    substr(md5(city.id::text || ':' || emd.emd), 18, 3) || '-' ||
    substr(md5(city.id::text || ':' || emd.emd), 21, 12)
  )::uuid as id,
  emd.emd as name,
  city.id as parent_id,
  3 as level
from tmp_vworld_emd emd
join public.regions root
  on root.parent_id is null
 and root.level = 1
 and root.name = emd.sido
join public.regions city
  on city.parent_id = root.id
 and city.level = 2
 and city.name = emd.sigungu
left join public.regions existing
  on existing.parent_id = city.id
 and existing.name = emd.emd
where emd.sido = '경기도'
  and emd.emd like '%구'
  and existing.id is null;

-- level2 경계 upsert
insert into public.region_boundaries (
  region_id,
  geometry,
  bbox,
  center,
  source,
  source_version,
  synced_at
)
select
  r.id,
  s.geometry::jsonb,
  coalesce(s.bbox::jsonb, '[]'::jsonb),
  coalesce(s.center::jsonb, '[]'::jsonb),
  'vworld',
  :'source_version',
  now()
from tmp_vworld_sigungu s
join public.regions root
  on root.parent_id is null
 and root.level = 1
 and root.name = s.sido
join public.regions r
  on r.parent_id = root.id
 and r.name = s.sigungu
on conflict (region_id)
do update
set
  geometry = excluded.geometry,
  bbox = excluded.bbox,
  center = excluded.center,
  source = excluded.source,
  source_version = excluded.source_version,
  synced_at = excluded.synced_at;

-- level3(구) 경계 upsert
insert into public.region_boundaries (
  region_id,
  geometry,
  bbox,
  center,
  source,
  source_version,
  synced_at
)
select
  r3.id,
  e.geometry::jsonb,
  coalesce(e.bbox::jsonb, '[]'::jsonb),
  coalesce(e.center::jsonb, '[]'::jsonb),
  'vworld',
  :'source_version',
  now()
from tmp_vworld_emd e
join public.regions root
  on root.parent_id is null
 and root.level = 1
 and root.name = e.sido
join public.regions r2
  on r2.parent_id = root.id
 and r2.level = 2
 and r2.name = e.sigungu
join public.regions r3
  on r3.parent_id = r2.id
 and r3.level = 3
 and r3.name = e.emd
on conflict (region_id)
do update
set
  geometry = excluded.geometry,
  bbox = excluded.bbox,
  center = excluded.center,
  source = excluded.source,
  source_version = excluded.source_version,
  synced_at = excluded.synced_at;

insert into public.region_sync_meta (
  source_version,
  synced_at,
  notes
)
values (
  :'source_version',
  now(),
  'regions-sync-vworld.sh automated sync (semi-annual)'
)
on conflict (source_version)
do update
set
  synced_at = excluded.synced_at,
  notes = excluded.notes;

commit;
SQL

echo "[regions-sync] completed. source_version=${SOURCE_VERSION}"
