#!/usr/bin/env bash
set -euo pipefail

# Fetch latest digest for python:3.11-slim and suggest pinning to immutable digest to reduce supply-chain drift.

IMAGE="python:3.11-slim"
echo "[digest] Resolving latest digest for $IMAGE" >&2
REF=$(docker pull -q "$IMAGE" | tail -n1)
ID=$(docker image inspect --format '{{.Id}}' "$IMAGE")
DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE" | cut -d'@' -f2 || true)
echo "Image ID: $ID" >&2
echo "Digest : $DIGEST" >&2
echo
echo "Suggested Dockerfile FROM line:" >&2
echo "FROM $IMAGE@$DIGEST" | tee /dev/stderr
echo
echo "(Commit the change after verifying no regressions; rebuild images and scan again.)" >&2
