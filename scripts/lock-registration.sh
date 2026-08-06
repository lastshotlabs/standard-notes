#!/usr/bin/env bash
set -euo pipefail

env_file=/etc/homeserver/standard-notes.env
app_dir=/mnt/storage/apps/standard-notes

if [[ $EUID -ne 0 ]]; then
  echo "run with sudo" >&2
  exit 1
fi

if grep -q '^DISABLE_USER_REGISTRATION=true$' "$env_file"; then
  echo "registration is already disabled"
else
  sed -i 's/^DISABLE_USER_REGISTRATION=.*/DISABLE_USER_REGISTRATION=true/' "$env_file"
fi

chown deploy:deploy "$env_file"
chmod 0600 "$env_file"
sudo -u deploy env HOME=/home/deploy docker compose --project-directory "$app_dir" up -d --no-deps --force-recreate server

echo "registration disabled; existing accounts can still sign in and sync"

