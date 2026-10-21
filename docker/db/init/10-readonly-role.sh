#!/bin/bash
# Runs once, when the database volume is created: extensions plus a read-only role for the AI tools.
# The app's own role is the superuser created by the image (POSTGRES_USER). Table privileges of
# yadvault_ro are set by `yadvault db upgrade` after every migration:
# SELECT on the archive tables only, never on accounts, sessions, tokens or settings.
set -euo pipefail

: "${YADVAULT_RO_PASSWORD:?YADVAULT_RO_PASSWORD must be set}"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS vector;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'yadvault_ro') THEN
            CREATE ROLE yadvault_ro LOGIN PASSWORD '${YADVAULT_RO_PASSWORD}';
        END IF;
    END
    \$\$;
    GRANT CONNECT ON DATABASE "$POSTGRES_DB" TO yadvault_ro;
    GRANT USAGE ON SCHEMA public TO yadvault_ro;
EOSQL
