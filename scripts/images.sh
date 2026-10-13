#!/usr/bin/env bash
# Build governed-agent's images from its pinned tag, plus the in-cluster Git server.
# Tags are immutable and match the source tag; nothing here is ever tagged latest.
set -euo pipefail
cd "$(dirname "$0")/.."
. ./versions.env

src=$(mktemp -d)
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$GA_REF" "$GA_REPO" "$src"
echo "governed-agent $GA_REF at $(git -C "$src" rev-parse --short HEAD)"
docker build --quiet -t "governed-agent-python:$GA_REF" -f "$src/docker/python.Dockerfile" "$src" &
docker build --quiet -t "governed-agent-web:$GA_REF" -f "$src/docker/web.Dockerfile" "$src" &
docker build --quiet -t "local-git-server:$LOCAL_GIT_TAG" local-git &
wait
