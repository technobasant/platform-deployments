#!/usr/bin/env bash
# Static checks for terraform/aws. Nothing here talks to an AWS account: init runs
# without a backend and validate needs no credentials.
set -euo pipefail
cd "$(dirname "$0")/.."
. ./versions.env
tf=terraform/aws
cache=${TF_PLUGIN_CACHE:-$PWD/.cache/terraform}
mkdir -p "$cache"
run() { docker run --rm -v "$PWD":/work -v "$cache":/cache -e TF_PLUGIN_CACHE_DIR=/cache -w /work "$@"; }

echo "== terraform fmt -check"
run "$TERRAFORM_IMAGE" fmt -check -recursive -diff "$tf"
echo "== terraform validate"
run -w "/work/$tf/envs/demo" "$TERRAFORM_IMAGE" init -backend=false -input=false -no-color >/dev/null
run -w "/work/$tf/envs/demo" "$TERRAFORM_IMAGE" validate -no-color
echo "== tflint"
run -w "/work/$tf" --entrypoint sh "$TFLINT_IMAGE" -c \
  "tflint --init >/dev/null && tflint --recursive --config /work/$tf/.tflint.hcl --format compact"
echo "== trivy config (HIGH, CRITICAL)"
run "$TRIVY_IMAGE" config --quiet --exit-code 1 --severity HIGH,CRITICAL "$tf"
echo "== checkov"
run "$CHECKOV_IMAGE" -d "$tf" --framework terraform --quiet --compact
echo "terraform checks passed"
