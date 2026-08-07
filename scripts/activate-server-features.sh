#!/usr/bin/env bash
set -euo pipefail

app_dir=/mnt/storage/apps/standard-notes

if [[ $EUID -ne 0 ]]; then
  echo "activation must run as root" >&2
  exit 1
fi

mysql() {
  sudo -u deploy env HOME=/home/deploy docker compose --project-directory "$app_dir" \
    exec -T db sh -c \
    'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql --batch --skip-column-names --user=root "$MYSQL_DATABASE"'
}

user_count=$(mysql <<'SQL'
SELECT COUNT(*) FROM users;
SQL
)

if [[ $user_count != 1 ]]; then
  echo "refusing activation: expected exactly one user, found $user_count" >&2
  exit 1
fi

"$app_dir/scripts/backup.sh"

mysql <<'SQL'
START TRANSACTION;

INSERT INTO user_roles (role_uuid, user_uuid)
SELECT
  (SELECT uuid FROM roles WHERE name = 'PRO_USER' ORDER BY version DESC LIMIT 1),
  users.uuid
FROM users
ON DUPLICATE KEY UPDATE role_uuid = VALUES(role_uuid);

INSERT INTO user_subscriptions (
  uuid,
  plan_name,
  ends_at,
  created_at,
  updated_at,
  user_uuid,
  subscription_id,
  subscription_type
)
SELECT
  UUID(),
  'PRO_PLAN',
  8640000000000000,
  0,
  0,
  users.uuid,
  1,
  'regular'
FROM users
WHERE NOT EXISTS (
  SELECT 1
  FROM user_subscriptions
  WHERE user_subscriptions.user_uuid = users.uuid
    AND user_subscriptions.plan_name = 'PRO_PLAN'
);

COMMIT;
SQL

pro_role_count=$(mysql <<'SQL'
SELECT COUNT(*)
FROM user_roles
JOIN roles ON roles.uuid = user_roles.role_uuid
WHERE roles.name = 'PRO_USER';
SQL
)

pro_subscription_count=$(mysql <<'SQL'
SELECT COUNT(*)
FROM user_subscriptions
WHERE plan_name = 'PRO_PLAN';
SQL
)

if [[ $pro_role_count != 1 || $pro_subscription_count != 1 ]]; then
  echo "activation verification failed: roles=$pro_role_count subscriptions=$pro_subscription_count" >&2
  exit 1
fi

echo "server-side Pro features active: roles=$pro_role_count subscriptions=$pro_subscription_count"
