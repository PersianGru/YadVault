#!/usr/bin/env bash
# Restore a backup made by scripts/backup.sh or in Settings → Backups into a compose deployment.
#
#   scripts/restore.sh backups/yadvault-20260101-120000.tar.age path/to/age-key.txt
#   scripts/restore.sh backups/yadvault-20260101-120000.tar          (a backup that was not encrypted)
#
# A backup made in Settings is in the app's data volume: copy it out first with
#   docker compose cp app:/data/backups/yadvault-20260101-120000.tar.age backups/
#
# Stops the running services except the database, replaces the database contents and the data
# folder, and starts the same services again (migrations run on start). Needs docker compose and
# age. Run from the repo root. Plain POSIX sh, so `sh scripts/restore.sh` works without bash.
set -eu

src="${1:?usage: scripts/restore.sh <backup.tar.age> <age identity file>  (or <backup.tar>)}"
identity="${2:-}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

set -a; [ -f .env ] && . ./.env; set +a
db_user="${POSTGRES_USER:-yadvault}"
db_name="${POSTGRES_DB:-yadvault}"

case "$src" in
  *.age)
    [ -n "$identity" ] || { echo "the backup is encrypted: give the age key file as the second argument" >&2; exit 1; }
    command -v age >/dev/null || { echo "age is not installed (https://age-encryption.org)" >&2; exit 1; }
    echo "decrypting..."
    age -d -i "$identity" "$src" > "$work/backup.tar"
    ;;
  *) cp "$src" "$work/backup.tar" ;;
esac
tar -C "$work" -xf "$work/backup.tar" && rm -f "$work/backup.tar"
[ -f "$work/database.pgdump" ] || { echo "not an yadvault backup" >&2; exit 1; }

# only what runs now comes back afterwards (a host without the embeddings service stays without it)
running="$(docker compose ps --services --status running | tr '\n' ' ')"
case " $running " in *" db "*) ;; *) echo "the db service is not running: start it first (docker compose up -d db)" >&2; exit 1;; esac
others="$(printf '%s\n' $running | grep -vx db | tr '\n' ' ' || true)"
if [ -n "$(echo "$others" | tr -d ' ')" ]; then
  echo "stopping $others..."
  docker compose stop $others
fi
echo "restoring database ${db_name} (existing data is replaced)..."
docker compose exec -T db pg_restore -U "$db_user" -d "$db_name" --clean --if-exists --no-owner --no-privileges < "$work/database.pgdump" \
  || echo "pg_restore reported ignorable errors (objects that did not exist yet)"
if [ -d "$work/data" ]; then
  echo "restoring avatars and attachments..."
  docker compose start app
  for sub in avatars attachments media profiles; do
    if [ -d "$work/data/$sub" ]; then docker compose cp "$work/data/$sub" "app:/data/" || true; fi
  done
  if [ -f "$work/data/keys/secret.key" ]; then
    echo "restoring the key of the stored secrets..."
    # written by the app's own user, readable by it only
    docker compose exec -T app sh -c 'umask 077 && mkdir -p /data/keys && cat > /data/keys/secret.key' < "$work/data/keys/secret.key"
  fi
fi
echo "starting $running again (migrations run on start)..."
docker compose up -d $running
echo "restore finished"
