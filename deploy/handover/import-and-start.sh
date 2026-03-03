#!/usr/bin/env bash
set -euo pipefail

IMAGE_ARCHIVE="${1:-postal-api-extended-image.tar.gz}"
COMPOSE_FILE="docker-compose.handover.yml"
ENV_FILE=".env"

if [ ! -f "$IMAGE_ARCHIVE" ]; then
  echo "Missing image archive: $IMAGE_ARCHIVE" >&2
  exit 1
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE (copy from .env.example and adjust values)" >&2
  exit 1
fi

if [ ! -f "./config/postal.yml" ]; then
  echo "Missing ./config/postal.yml (copy and adapt ./config/postal.production.example.yml)" >&2
  exit 1
fi

if [ ! -f "./config/signing.key" ]; then
  echo "Missing ./config/signing.key" >&2
  exit 1
fi

echo "[handover] Loading Docker image from $IMAGE_ARCHIVE"
docker load -i "$IMAGE_ARCHIVE"

echo "[handover] Starting database"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d mariadb

echo "[handover] Running Postal initialize (safe to rerun for initial setup)"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" run --rm postal-web postal initialize

echo "[handover] Starting Postal services"
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d postal-web postal-worker postal-smtp

echo "[handover] Done"
