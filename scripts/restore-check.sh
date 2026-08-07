#!/usr/bin/env bash
set -euo pipefail

backup_env=/etc/homeserver/standard-notes-backup.env

if [[ $EUID -ne 0 ]]; then
  echo "restore check must run as root" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$backup_env"
set +a

restore_dir=$(mktemp -d /var/tmp/standard-notes-restore.XXXXXX)
trap 'rm -rf -- "$restore_dir"' EXIT

restic restore latest --tag standard-notes --target "$restore_dir"

dump_path=$(find "$restore_dir" -type f -name standard-notes.sql.gz -print -quit)
if [[ -z "$dump_path" ]]; then
  echo "restored snapshot does not contain the database dump" >&2
  exit 1
fi

gzip -t "$dump_path"
zgrep -Fq 'CREATE TABLE `users`' "$dump_path"
zgrep -Fq 'CREATE TABLE `user_roles`' "$dump_path"
zgrep -Fq 'CREATE TABLE `user_subscriptions`' "$dump_path"
test -s "$restore_dir/etc/homeserver/standard-notes.env"

echo "latest snapshot restored successfully and contains a valid SQL dump"
