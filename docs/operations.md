# Operations

Running the compose deployment day to day: updates, backups, network, hardware and what to do
when something does not work.

## Services and profiles

`docker compose up -d` starts `db`, `app` and `worker`, plus the profiles named in
`COMPOSE_PROFILES` in `.env` (`.env.example` names `embeddings`). Profiles add optional services:

| Profile | Services | Purpose |
|---|---|---|
| `embeddings` | `embeddings-download` (one-shot), `embeddings` | Semantic search on this server (see [Semantic search](#semantic-search)) |
| `avatars` | `avatar-fetcher` | The Bulk sync add-on's fetcher (Pro; no login ever), the only service with internet access |
| `llm` | `ollama`, `openwebui` | A model server (gateway address `http://ollama:11434/v1`) and a chat UI, for people without an LLM gateway yet |

`docker compose --profile embeddings --profile avatars up -d` starts several at once. Profiles
are remembered per command, so include them in `down` and `logs` calls too, or set
`COMPOSE_PROFILES=embeddings,avatars` in `.env`. HTTPS is not a profile but an optional override
file, `docker-compose.https.yml` (see [HTTPS](https.md)). The MCP server needs no profile: the app
serves it at `/mcp` (see [API](api.md#mcp-server)).

### Bulk sync (add-on, Pro)

The add-on looks the people in your archive up on Instagram's public pages, in bulk and at a
careful pace, without a login, through the `avatar-fetcher` service. It is part of YadVault Pro. Both are off by default: the service is not started, and the
switch in Settings is off. To run it:

1. In `.env`, point the app at the service and start the service's profile (keep any profile
   already listed, comma-separated):

   ```
   AVATAR_FETCHER_URL=http://avatar-fetcher:8002
   COMPOSE_PROFILES=embeddings,avatars
   ```

2. `docker compose up -d`: it pulls the service, starts it, and recreates `app` and
   `worker` with the address.
3. In Settings → Bulk sync, read the warning and turn the add-on on.

Until both are done, Settings → Bulk sync says so, and a person's page explains why it
cannot look anyone up instead of offering it. The service is the only container with internet
access. What it does and how it stays out of trouble:

- It never logs in (no session files, cookies or proxies) and sees only what Instagram shows
  anyone who is logged out: a profile's public details, its picture and, when Instagram embeds
  them for logged-out visitors, the latest posts and reels (about 12). For many profiles Instagram
  shows no posts at all without a login; the person's page then says so. Private accounts give
  details only; stories, highlights, followers and older posts are never asked for.
- It downloads only over https from Instagram's media servers, also after redirects, and keeps
  nothing on disk; the app re-encodes every picture it stores.
- It stops at the first sign of a limit: the queue pauses on its own (15 minutes after the first
  block, twice as long after each further block in a row, at most 6 hours) and slows down.
  Lookups are at least `AVATAR_FETCH_PACE_SECONDS` (15) apart; the queue starts at one profile
  every 90 seconds and speeds up only slowly while nothing is blocked.
- It looks up only the people you queue (Settings → Bulk sync, a person's *Look up*, or the
  People page), and only while the add-on is on.

Read the warning in Settings before enabling it: this uses Instagram's unofficial web access, may
stop working at any time, can get the server's address temporarily blocked, and automated
collection may break Instagram's Terms of Use.

The image's command picks its role: `serve` (web UI, API and MCP), `worker` (the background jobs),
or `all`, the web UI and the jobs in one container, which the NAS templates in
[install/](../install/README.md) use. Every role validates the configuration and applies the
migrations first; when the database has no read-only role for the AI tools yet, it is created from
`YADVAULT_READONLY_DATABASE_URL`.

## First start

The setup wizard asks for a one-time setup code, so whoever reaches the port first cannot claim
the archive. The app prints it to its log at every start until the first account exists:

```bash
docker compose logs app | grep "setup code"
```

Set `YADVAULT_SETUP_CODE` in `.env` to choose the code yourself, or create the first admin from
the command line instead: `docker compose exec app yadvault users create <name> --role admin`.

## Updating

```bash
scripts/backup.sh <age recipient>     # first
docker compose pull
docker compose up -d
```

Migrations run automatically when `app` and `worker` start, under a database lock, so the order
does not matter. Downgrades are not supported: restore a backup to go back. Release notes are in
[CHANGELOG.md](../CHANGELOG.md); versions follow semantic versioning and breaking changes are
called out there.

## Backups and restore

### From Settings

**Settings → Backups** (admins) makes backups without a terminal: **Back up now**, or every day
or every week at an hour you choose (in your time zone), keeping the newest few (7 unless you
change it) and removing older ones after each backup. They go to `/data/backups` in the data
volume; with `docker-compose.backups.yml` they go to a folder on the host instead (another disk or
a mounted share; see the comments in that file), which is better: a backup should not live on the
disk it protects. **Download** copies one to your computer. A failed backup shows in the bell (and
goes to the webhook, if you set one).

Backups are encrypted with [age](https://age-encryption.org) when a key is set. **Create a key**
makes one on the server and shows the secret key once: save it somewhere else (a password
manager, a USB stick), tick that you did, and only its public half is kept. You can also paste the
public key (`age1...`) of a key you already have. Without a key, backups are plain tar files and
anyone who gets one can read the whole archive. Either way, a backup file can be read only by the
user the app runs as (and root), and so can a backup folder the app creates; on a share that
ignores file modes, the share's own permissions decide.

Restoring replaces everything, so it stays a server command: copy the backup out of the volume
(or take the downloaded file) and run the restore script with your key:

```bash
docker compose cp app:/data/backups/yadvault-20260101-030000.tar.age backups/
scripts/restore.sh backups/yadvault-20260101-030000.tar.age yadvault-backup-key.txt
scripts/restore.sh backups/yadvault-20260101-030000.tar        # a backup made without a key
```

The image carries `pg_dump` and `pg_restore` of PostgreSQL 16 (the database's version) and age.
Without Docker, install the PostgreSQL client tools of your database's version (or set
`YADVAULT_PG_BIN`) and age; `YADVAULT_BACKUP_DIR` moves the backup folder.

### From the command line

The database holds everything you imported and everything you added; the data volume holds
profile pictures, attachments of messages you added, the photos, videos and voice messages you
chose to copy at import (`media/`) and the key file that opens the stored secrets
([encryption.md](encryption.md)). One backup covers both; thumbnails are left out (they are
made again when needed), and `NO_MEDIA=1 scripts/backup.sh ...` (or `yadvault backup --no-media`)
leaves out the copied media when you keep the exports themselves somewhere safe:

```bash
age-keygen -o archive-key.txt            # once; keep this file off the server
grep public archive-key.txt               # the recipient (age1...)
scripts/backup.sh age1...                 # writes backups/yadvault-<date>.tar.age
scripts/restore.sh backups/yadvault-<date>.tar.age archive-key.txt
```

`restore.sh` stops the running services except the database, replaces the database contents
and the data folder, and starts the same services again (migrations run on start); services
that were not running, such as an embeddings service you left out on a small host, stay off.
Both scripts are plain POSIX sh: on a host without bash (Alpine, BusyBox) run them as
`sh scripts/backup.sh ...`. Try a restore once on a fresh install so you know your key works.
Schedule the backup with cron and copy the files somewhere else; the files are useless without
the key, so they can travel.

Without Docker, `yadvault backup --recipient age1... backup.tar.age` and
`yadvault restore backup.tar.age --identity archive-key.txt` do the same with the PostgreSQL
client tools on PATH (or `YADVAULT_PG_BIN`).

## Network

- Ports: 8000 (web UI, API and MCP), 3000 (Open WebUI), 443 (Caddy, with HTTPS on; no plain-HTTP
  port). They bind to `BIND_ADDRESS` from `.env`.
- Keep them on the LAN. Never forward them on the router. A host firewall rule limited to your
  subnet is the simplest extra guard. Linux with ufw:

  ```bash
  sudo ufw allow from 192.168.1.0/24 to any port 8000 proto tcp
  sudo ufw deny 8000/tcp
  ```

  Docker publishes ports through its own iptables chain; ufw rules apply when `BIND_ADDRESS` is
  the host's LAN address rather than `0.0.0.0`, or use `DOCKER-USER` chain rules.
- HTTPS (optional): `docker-compose.https.yml` runs Caddy in front of the app and closes port
  8000; nothing listens for plain HTTP. The certificate comes from Caddy's own certificate
  authority (devices install it once, from Settings → HTTPS, which also shows its expiry, can
  make a new one and sets how long server certificates last) or from Let's Encrypt, through the
  DNS challenge (the server stays on the LAN) or the TLS-ALPN challenge. [docs/https.md](https.md)
  has the setup for each, the steps to install the certificate on Windows, macOS, iPhone,
  Android, Linux and Firefox, and troubleshooting. Behind a reverse proxy of your own instead, set `PROXY_HEADERS=true` and
  `FORWARDED_ALLOW_IPS` to that proxy's address only: with `*` and port 8000 reachable, any
  client could choose the address the login limits count.
- An LLM gateway elsewhere on the LAN (LiteLLM, for example): the app only needs to reach its
  address. Open WebUI needs to reach the archive only to use its tools over MCP (`/mcp` on the app).
- Single sign-on ([docs/sso.md](sso.md)): the app container needs outbound HTTPS to the provider
  (`login.microsoftonline.com`, or your Okta domain); set `HTTPS_PROXY` in `.env` when it goes
  through a proxy. People's browsers reach the provider directly.

## Semantic search

Search by meaning, in any language, also used by Ask. Conversations are cut into short windows
and an embedding model turns each into a vector. Settings → Semantic search chooses where the
vectors come from; *Test* embeds a few sample sentences and shows the model, its size and speed.

- **On this server** (`local`, the default): the `embeddings` profile runs one model in its own
  container, offline after a one-time download. Pick it with `EMBEDDINGS_MODEL` in `.env`:

  | Model | Dimensions | RAM | Windows/s, 12 cores | Use it for |
  |---|---|---|---|---|
  | `intfloat/multilingual-e5-small` (default) | 384 | about 1 GB | about 150 | Small servers, CPU only |
  | `intfloat/multilingual-e5-base` | 768 | about 2 GB | about 60 | More accuracy, still fine on CPU |
  | `BAAI/bge-m3` | 1024 | about 4 GB | about 20 | Best quality, long texts; a GPU or a big CPU |
  | `Qwen/Qwen3-Embedding-0.6B` | 1024 | about 3 GB | slow on CPU | Top quality for its size; a GPU |
  | `sentence-transformers/all-MiniLM-L6-v2` | 384 | under 1 GB | fast | Archives in a single language it covers (see its model card) |

  The first four handle text in about 100 languages. Speeds are this project's measurements
  (12 CPU cores; divide by about six for two); a GPU is ten or more times faster. Raise
  `EMBEDDINGS_MEMORY_LIMIT` to 6g for bge-m3 or Qwen3. Gated models such as
  `google/embeddinggemma-300m` need `HF_TOKEN` in `.env` for the download.
- **Through the LLM gateway** (`gateway`): any embedding model your gateway offers, such as
  LiteLLM with OpenAI `text-embedding-3-small`, or Ollama's `bge-m3`, `qwen3-embedding`,
  `embeddinggemma` or `snowflake-arctic-embed2`. Nothing extra runs on this server; leave
  `embeddings` out of `COMPOSE_PROFILES`. The worker builds the index, so it needs a route to the
  gateway: add `COMPOSE_FILE=docker-compose.yml:docker-compose.gateway.yml` to `.env`. The text
  of your conversations goes to wherever that model runs: a model on your own network keeps it
  there, a cloud model receives it. *Dimensions* asks models that can shorten their vectors
  (OpenAI text-embedding-3) for fewer. Keep the family name in gateway aliases (e5, nomic,
  embeddinggemma, qwen3-embedding) so queries and documents get the prefixes the model expects.
- **Off**: keyword search only; imports queue no embedding job.

Vectors of two models cannot be compared, so the index belongs to one model. After a switch
(another model, or another number of dimensions) semantic search pauses, keyword search keeps
working, and Settings → Semantic search offers *Rebuild the index*. The vector column follows the
model's size (`vector` up to 2,000 dimensions, `halfvec` up to 4,000).

## Hardware

- **CPU only** works everywhere. A million messages make about 100,000 windows: with the
  default model about 10 minutes on 12 cores and an hour on two, with bge-m3 a few hours (see
  [Semantic search](#semantic-search)); keyword search works immediately and semantic search fills
  in as the index grows. The job is resumable and runs in the background.
- **NVIDIA GPU (amd64):** install the NVIDIA container toolkit and add the GPU file, for example
  `COMPOSE_FILE=docker-compose.yml:docker-compose.gpu.yml` in `.env`, then `docker compose up -d`.
  The embeddings service then runs the CUDA image (`-cuda` tag, several GB) and is about ten
  times faster; Ollama in the `llm` profile gets the GPU too.
- **Memory:** limits per service are in `.env` (`DB_MEMORY_LIMIT`, `WORKER_MEMORY_LIMIT`, ...).
  The worker's limit bounds the importer; an import of a multi-GB export runs within about 1 GB
  but raising the limit lets more parser processes work in parallel.
- **Watch folder (unfollower tracker):** turn it on in Settings → Import and add
  `docker-compose.watch.yml` (see `.env.example`); exports dropped into `./watch` (one zip, or a
  folder with the export or all its zip parts) are imported once they stop changing for a
  minute, and the bell (and an optional webhook such as ntfy, with counts only) says who
  unfollowed you. Each export is imported once.
- **Network folder (Pro):** instead of a folder mounted into Docker, Settings → Import can name a
  shared folder on your NAS, PC or Mac (`smb://server/share/folder`; Windows file sharing, macOS
  File Sharing, Samba), public or with a username and password (kept encrypted). The worker
  reads it itself over SMB every 30 seconds, copies an export that has not changed for a minute
  to the server, imports it like the watch folder's and removes the copy (the original too when
  "delete after import" is on). *Test the connection* lists what the folder holds. Give the
  account read access, and write access only for deleting. Only SMB is spoken; an NFS export can
  still be mounted on the host and used through `docker-compose.watch.yml`.
- **Storage page:** Settings → Storage shows free disk space, what the database and the data
  folder hold, the biggest conversations and people, and cleanup tasks (left-over uploads,
  thumbnails, media of rolled-back imports, leftovers of interrupted work, copied media by kind
  or person, the semantic search index, a database tidy). Each runs as a background job and
  reports what it freed. Uploaded exports stay 7 days after their import (Settings → Import) so
  their media can still be copied; set 0 to delete them at once.
- **Disk:** about 0.6 GB of database per million messages plus the extracted export during the
  import (deleted afterwards unless `Keep uploads` is on) and the model cache (0.5 GB for the
  default model, 2.3 GB for bge-m3). Copied media take what the import page shows for the kinds
  you choose (a file that is already in the archive takes no more space); the media job stops
  before it would leave less than 1 GB free.

## Logs

`docker compose logs -f app worker` prints one JSON object per line: time, level, logger,
message and, for requests, method, path, status and duration. Query strings and bodies are never
logged. `LOG_FORMAT=text` switches to plain lines, `LOG_LEVEL=debug` adds detail.

## Health

`GET /api/health` answers as soon as the process is up; `GET /api/ready` also checks the
database. Docker's health checks use them; `docker compose ps` shows the state. The embeddings
service has `/health` and `/info`, the fetcher `/health`.

## Troubleshooting

- **`app` keeps restarting with "cannot connect to the database".** The database takes a moment
  on first start; `YADVAULT_STARTUP_WAIT` (default 120 s) is how long the app waits. Check
  `docker compose logs db` for a disk or password problem.
- **"the pgvector extension is not available".** The `db` service must use the
  `pgvector/pgvector:pg16` image (it does by default); an existing plain PostgreSQL volume
  cannot be reused.
- **Semantic search is off or paused.** Settings → Semantic search shows the provider, the error
  and whether the index belongs to another model (then *Rebuild the index*). On this server:
  `docker compose logs embeddings-download` shows whether the model download succeeded (the
  one-shot job needs huggingface.co once), `docker compose logs embeddings` the model loading.
  Through the gateway: *Test* shows the gateway's answer; an embedding job that fails with "not
  reachable" while *Test* works means the worker has no route to the gateway (see
  `docker-compose.gateway.yml`).
- **The import stopped.** Imports checkpoint every file: start the worker again and the job
  resumes, or press *Resume* on the Import page. A job whose worker died (killed, out of
  memory) is re-queued automatically within a minute of the worker coming back.
- **Ask says the LLM gateway is not configured or unreachable.** Settings → LLM gateway → *Test
  connection* shows the exact error and the API root it called (it lists `<API root>/models`).
  From inside the container the address must be reachable:
  `docker compose exec app python -c "import httpx; print(httpx.get('http://litellm:4000/v1/models').status_code)"`
  (401 means reachable, but the key is missing or wrong).
- **Settings says a stored key or client secret must be entered again.** The key that sealed it
  is gone (a database restored without its key file, or a changed `YADVAULT_SECRET_KEY`). Enter
  the secret again; `docker compose exec app yadvault secrets status` shows which key is in use
  ([encryption.md](encryption.md)).
- **Reset everything.** `docker compose down -v` deletes the volumes (database, pictures, model
  cache, the key of the stored secrets). Back up first.
