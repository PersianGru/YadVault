# Installing YadVault on a NAS or home server

Ready-made templates for the common home-server platforms. They all run two containers: the
database (PostgreSQL 16 with pgvector) and YadVault itself as one container that serves the web UI
and runs the background jobs (`all`). That suits a home archive; for very large archives, the
embeddings service or the MCP server, use the full stack in the repository root (`docker-compose.yml`
and docs/operations.md).

| Platform | Template | How |
|---|---|---|
| Synology DSM 7.2+ | [synology/docker-compose.yml](synology/docker-compose.yml) | Container Manager → Project → Create ([guide](synology/README.md)) |
| TrueNAS SCALE 24.10+ | [truenas/docker-compose.yml](truenas/docker-compose.yml) | Apps → Install via YAML ([guide](truenas/README.md)) |
| Unraid 6.12+ | [unraid/yadvault-db.xml](unraid/yadvault-db.xml), [unraid/yadvault.xml](unraid/yadvault.xml) | Docker templates ([guide](unraid/README.md)) |
| CasaOS | [casaos/docker-compose.yml](casaos/docker-compose.yml) | App Store → Custom Install → Import ([guide](casaos/README.md)) |
| umbrelOS | [umbrel/yadvault](umbrel/yadvault) | a community app store folder ([guide](umbrel/README.md)) |

## The same on every platform

1. **Passwords.** Replace `CHANGE-ME` (in two places: the database and
   YadVault's database address) and `CHANGE-ME-TOO` (the read-only role of the AI tools,
   created at the first start) with passwords of letters and digits. YadVault refuses to start
   while a `CHANGE-ME` is left. umbrelOS fills them in itself. If you started the database once with
   the placeholder, delete its volume or folder before the next try (it keeps its first password).
2. **First start.** The YadVault container's log shows a one-time setup code. Open the web UI
   (port 8000), enter the code and create your account. The first start also creates the database
   tables, which takes a few seconds.
3. **Import.** Request your data export from Instagram (or Facebook, for Messenger) in JSON format
   and upload the zip files on the Import page.
4. **Backups.** Settings → Backups makes them (now, or every day or week) into the data folder;
   download them to keep a copy elsewhere. Restoring is described in docs/operations.md.
5. **Updates.** Pull the new image and recreate the YadVault container; the database is migrated
   at start. Back up first.

Semantic search is off in these templates (no embeddings service); with YadVault Pro it can use an
embedding model at your LLM gateway (Settings → Semantic search). The containers never reach the
internet on their own.

