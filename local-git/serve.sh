#!/bin/sh
# Serve one bare repository over smart HTTP (fetch and push) with dulwich.
set -eu
repo=/srv/platform-deployments.git
[ -d "$repo" ] || git init -q --bare -b main "$repo"
git -C "$repo" config http.receivepack true
exec python -m dulwich.web --listen_address 0.0.0.0 --port 8080 "$repo"
