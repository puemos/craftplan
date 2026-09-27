#!/bin/sh
set -eu
umask 077
: "${S3_BUCKET:=craftplan}"
: "${AWS_ACCESS_KEY_ID:?Storage access key is required}"
: "${AWS_SECRET_ACCESS_KEY:?Storage secret key is required}"
export S3_BUCKET
mkdir -p /data
exec 9>/data/.craftplan-storage.lock
fail() {
  echo "$1" >&2
  exit 1
}

flock -n 9 || fail 'Another storage process owns this data volume.'
marker=/data/.craftplan-storage-v1
pending=/data/.craftplan-minio-pending
snapshot=/data/.craftplan-minio-snapshot
source_pid=
weed_pid=

cleanup() {
  [ -z "$source_pid" ] || kill "$source_pid" 2>/dev/null || true
  [ -z "$weed_pid" ] || kill "$weed_pid" 2>/dev/null || true
  [ -z "$source_pid" ] || wait "$source_pid" 2>/dev/null || true
  [ -z "$weed_pid" ] || wait "$weed_pid" 2>/dev/null || true
  source_pid=
  weed_pid=
}

clear_migration() {
  rm -rf "$snapshot"
  rm -f "$pending"
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

mark_ready() {
  printf '%s\n' "$1" > "$marker.tmp"
  sync
  mv "$marker.tmp" "$marker"
  sync
}

start_storage() {
  if [ -f /data/mini.options ]; then
    sed -i '/^ip\.bind=/d' /data/mini.options
  fi
  echo 'Starting SeaweedFS; MinIO migration is not required.'
  exec weed mini -dir=/data -s3.port=9000 -ip=127.0.0.1 -ip.bind=0.0.0.0 -admin.ui=false
}

if [ -f "$marker" ]; then
  case "$(cat "$marker")" in
    v1:migrated:*|v1:native:*)
      clear_migration
      start_storage ;;
    *) fail 'Unrecognized storage marker; refusing to overwrite data.' ;;
  esac
fi

rm -f "$pending.tmp" "$marker.tmp"
legacy_entries=$(ls -A /legacy)
if [ ! -f "$pending" ] && [ -z "$legacy_entries" ]; then
  mark_ready "v1:native:$S3_BUCKET"
  start_storage
fi

if [ -f "$pending" ]; then
  [ "$(cat "$pending")" = "$S3_BUCKET" ] ||
    fail 'Restore the original S3_BUCKET to resume the interrupted migration.'
else
  existing=$(find /data -mindepth 1 \( -type f -o -type l \) ! -name '.craftplan-storage.lock' -print)
  [ -z "$existing" ] ||
    fail 'Both storage volumes contain data without a migration marker. Use manual recovery.'
  printf '%s\n' "$S3_BUCKET" > "$pending.tmp"
  mv "$pending.tmp" "$pending"
  sync
fi
[ -n "$legacy_entries" ] || fail 'Legacy data is missing; cannot resume migration.'

echo 'MinIO data detected. Taking a private snapshot; the original volume is read-only.'
rm -rf "$snapshot"
mkdir -p "$snapshot"
cp -a /legacy/. "$snapshot/"

export MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
export MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"
legacy-minio server "$snapshot" --address 127.0.0.1:19001 --console-address 127.0.0.1:19002 &
source_pid=$!
weed mini -dir=/data -s3.port=19000 -ip=127.0.0.1 -ip.bind=127.0.0.1 -admin.ui=false &
weed_pid=$!

wait_ready() {
  url=$1
  pid=$2
  count=0
  until wget -q --spider "$url"; do
    kill -0 "$pid" 2>/dev/null || fail 'A migration service failed to start.'
    count=$((count + 1))
    [ "$count" -lt 120 ] || fail 'Timed out starting migration services.'
    sleep 1
  done
}
wait_ready http://127.0.0.1:19001/minio/health/ready "$source_pid"
wait_ready http://127.0.0.1:19000/readyz "$weed_pid"

export RCLONE_CONFIG_OLD_TYPE=s3 RCLONE_CONFIG_OLD_PROVIDER=Minio
export RCLONE_CONFIG_OLD_ENDPOINT=http://127.0.0.1:19001
export RCLONE_CONFIG_OLD_ACCESS_KEY_ID="$MINIO_ROOT_USER"
export RCLONE_CONFIG_OLD_SECRET_ACCESS_KEY="$MINIO_ROOT_PASSWORD"
export RCLONE_CONFIG_OLD_REGION=us-east-1 RCLONE_CONFIG_OLD_FORCE_PATH_STYLE=true
export RCLONE_CONFIG_NEW_TYPE=s3 RCLONE_CONFIG_NEW_PROVIDER=SeaweedFS
export RCLONE_CONFIG_NEW_ENDPOINT=http://127.0.0.1:19000
export RCLONE_CONFIG_NEW_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export RCLONE_CONFIG_NEW_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
export RCLONE_CONFIG_NEW_REGION=us-east-1 RCLONE_CONFIG_NEW_FORCE_PATH_STYLE=true

rclone copy "old:$S3_BUCKET" "new:$S3_BUCKET" --ignore-times --metadata --stats-one-line
rclone check "old:$S3_BUCKET" "new:$S3_BUCKET" --download --one-way
cleanup
mark_ready "v1:migrated:$S3_BUCKET"
clear_migration
echo 'MinIO migration verified and completed. Future starts will skip migration.'
start_storage
