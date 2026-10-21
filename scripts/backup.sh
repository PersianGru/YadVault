#!/usr/bin/env bash
# Encrypted backup of a compose deployment: database dump plus the data volume (avatars,
# attachments, copied media, and the key that opens the stored secrets) in one tar, encrypted
# with age to your public key.
#
#   scripts/backup.sh age1yourpublickey... [backups/]
#   NO_MEDIA=1 scripts/backup.sh age1yourpublickey...   # without the copied photos and voice messages
#
# Needs: docker compose, age (https://age-encryption.org). Run from the repository root (where
# docker-compose.yml and .env are). Restore with scripts/restore.sh. Plain POSIX sh, so
# `sh scripts/backup.sh` works on hosts without bash.
set -eu
umask 077  # backups hold the whole archive: readable by their owner only

recipient="${1:?usage: scripts/backup.sh <age recipient> [output folder]}"
out_dir="${2:-backups}"
stamp="$(date +%Y%m%d-%H%M%S)"
out="${out_dir}/yadvault-${stamp}.tar.age"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

command -v age >/dev/null || { echo "age is not installed (https://age-encryption.org)" >&2; exit 1; }
mkdir -p "$out_dir"
set -a; [ -f .env ] && . ./.env; set +a
db_user="${POSTGRES_USER:-yadvault}"
db_name="${POSTGRES_DB:-yadvault}"

echo "dumping database ${db_name}..."
docker compose exec -T db pg_dump -U "$db_user" -Fc --no-owner --no-privileges "$db_name" > "$work/database.pgdump"
subs="avatars attachments"
[ "${NO_MEDIA:-0}" = "1" ] || subs="$subs media profiles"
echo "copying ${subs}..."
mkdir -p "$work/data"
for sub in $subs; do
  docker compose cp "app:/data/${sub}" "$work/data/${sub}" 2>/dev/null || true
done
rm -rf "$work/data/media/thumbs" "$work/data/media/.incoming"  # made again on demand
# the key file that opens the stored secrets (none when YADVAULT_SECRET_KEY is used: keep that one yourself)
if docker compose exec -T app test -f /data/keys/secret.key 2>/dev/null; then
  echo "copying the key of the stored secrets..."
  mkdir -p "$work/data/keys"
  docker compose exec -T app cat /data/keys/secret.key > "$work/data/keys/secret.key"
fi
printf 'created_at=%s\ndatabase=%s\ndata_dir=True\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$db_name" > "$work/backup.txt"
tar -C "$work" -cf "$work/backup.tar" database.pgdump backup.txt data
age -r "$recipient" -o "$out" "$work/backup.tar"
echo "backup written: $out ($(du -h "$out" | cut -f1))"
echo "keep the age identity (secret key) somewhere safe: without it the backup cannot be read."
