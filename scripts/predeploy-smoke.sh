#!/usr/bin/env bash
set -euo pipefail

docker compose config --quiet

if ! grep -q '^DISABLE_USER_REGISTRATION=' /etc/homeserver/standard-notes.env; then
  echo "production env is missing DISABLE_USER_REGISTRATION" >&2
  exit 1
fi

