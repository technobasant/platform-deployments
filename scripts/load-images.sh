#!/usr/bin/env bash
# Copy the locally built images into every kind node (they are never pushed anywhere).
set -euo pipefail
cd "$(dirname "$0")/.."
. ./versions.env
kind load docker-image --name "$CLUSTER" \
  "governed-agent-python:$GA_REF" "governed-agent-web:$GA_REF" "local-git-server:$LOCAL_GIT_TAG"
