#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-postal-api-extended:handover}"
OUTPUT="${2:-postal-api-extended-image.tar.gz}"

docker image inspect "$IMAGE" >/dev/null

echo "[handover] Exporting image: $IMAGE"
docker save "$IMAGE" | gzip > "$OUTPUT"
sha256sum "$OUTPUT" > "$OUTPUT.sha256"

echo "[handover] Wrote: $OUTPUT"
echo "[handover] Checksum: $OUTPUT.sha256"
