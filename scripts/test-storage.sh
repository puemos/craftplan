#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export COMPOSE_PROJECT_NAME="craftplan-storage-test-$$"
export MINIO_ROOT_USER=migration-user MINIO_ROOT_PASSWORD=migration-secret
export AWS_ACCESS_KEY_ID=replacement-user AWS_SECRET_ACCESS_KEY="replacement-secret\$literal"
export AWS_S3_BUCKET=craftplan-storage-test
export POSTGRES_PASSWORD=unused
export MINIO_ENDPOINT=http://minio:9000
compose=(docker compose -f test/integration/docker-compose.yml)
cleanup() {
  "${compose[@]}" down -v --remove-orphans
  for suffix in automatic_data empty_legacy fresh_data; do
    docker volume rm "${COMPOSE_PROJECT_NAME}_${suffix}" >/dev/null 2>&1 || true
  done
}
trap cleanup EXIT
docker build -f Dockerfile.storage -t craftplan-storage:test .
"${compose[@]}" up -d --wait seaweedfs minio
STORAGE_TEST_PORT=$("${compose[@]}" port seaweedfs 9000 | sed 's/.*://')
MINIO_TEST_PORT=$("${compose[@]}" port minio 9000 | sed 's/.*://')
export STORAGE_TEST_PORT MINIO_TEST_PORT
MIX_ENV="test" mix run --no-start test/integration/storage.exs

python3 test/integration/automatic_storage.py
