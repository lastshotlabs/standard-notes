#!/usr/bin/env bash
set -euo pipefail

app_dir=/mnt/storage/apps/standard-notes
app_env=/etc/homeserver/standard-notes.env
backup_env=/etc/homeserver/standard-notes-backup.env

if [[ $EUID -ne 0 ]]; then
  echo "backup must run as root" >&2
  exit 1
fi

if ! mountpoint -q /mnt/nas-backups; then
  echo "/mnt/nas-backups is not mounted" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$backup_env"
set +a

stage_dir=$(mktemp -d /var/tmp/standard-notes-backup.XXXXXX)
trap 'rm -rf -- "$stage_dir"' EXIT

sudo -u deploy env HOME=/home/deploy docker compose --project-directory "$app_dir" \
  exec -T db sh -c \
  'MYSQL_PWD="$MYSQL_PASSWORD" exec mysqldump --single-transaction --quick --skip-lock-tables --user="$MYSQL_USER" "$MYSQL_DATABASE"' \
  | gzip -9 > "$stage_dir/standard-notes.sql.gz"

gzip -t "$stage_dir/standard-notes.sql.gz"

restic backup \
  --tag standard-notes \
  "$stage_dir/standard-notes.sql.gz" \
  "$app_env" \
  "$app_dir/uploads" \
  "$app_dir/docker-compose.yml" \
  "$app_dir/localstack_bootstrap.sh"

restic forget \
  --tag standard-notes \
  --keep-daily 7 \
  --keep-weekly 5 \
  --keep-monthly 12 \
  --prune

