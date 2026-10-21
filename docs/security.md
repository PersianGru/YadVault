# Security model

What the archive protects, what it trusts, and what you still have to do yourself.

## What is at stake

Your Instagram export is years of private conversations with other people, plus everything
Instagram knows about your account. The archive keeps it on a machine you control and tries to
make sure that nothing leaves that machine unless you decide so.

## Where data flows

| Component | Reads | Writes | Network |
|---|---|---|---|
| `db` (PostgreSQL + pgvector) | | | internal network only, no route out |
| `app` (API + UI) | database, data volume | database, data volume | LAN port 8000; reaches your LLM gateway; reaches the fetcher when deployed |
| `worker` | database, data volume, embeddings service | database | internal network only; with `docker-compose.gateway.yml` also the LAN, to reach the LLM gateway for embeddings |
| `embeddings` | model cache | | internal network only; the one-shot `embeddings-download` reaches huggingface.co once |
| `mcp` (optional) | database (read-only role) | audit rows, optional notes | LAN port 8765 |
| `avatar-fetcher` (optional) | | | internal network and the internet (Instagram), only when you click |
| `openwebui`, `ollama` (optional) | | their own volumes | LAN port 3000; Ollama is internal only |

Message content goes to exactly one external place: the model you choose for Ask, through your
LLM gateway (the one address you configure). The app warns about this when a model is picked. Embeddings are computed on this server,
unless you choose an embedding model at your LLM gateway: then the conversation text goes there too.
Nothing is sent to the project's authors; there is no telemetry and no update check.

## Accounts and sessions

- The setup wizard creates the first admin, and only with the one-time setup code the app prints
  to its log (or `YADVAULT_SETUP_CODE`): reaching the port first is not enough. More users come
  from Settings → Users with the `admin` or `readonly` role. Read-only users browse, search and
  ask; they cannot change anything, and the model's optional note, tag and SQL tools are
  disabled for them.
- Passwords are hashed with argon2id. Sessions are random values in an HttpOnly, SameSite=Lax
  cookie, marked Secure when the request came over HTTPS; the server stores only their SHA-256
  hash, so a database dump or backup holds nothing that signs anyone in. They expire after 30
  days of inactivity (single sign-on sessions a fixed time after the sign-in, 24 hours by
  default). Changing the password ends every other session.
- State-changing requests from a session need the `X-CSRF-Token` header, which the UI sends. The
  token is derived from the session cookie and never stored.
- Logins are rate-limited per client address and per account (every spelling of a username counts
  against the same account), and a successful login does not reset the limits. Unknown usernames
  take as long to reject as wrong passwords.
- Single sign-on (Pro, [sso.md](sso.md)) uses OpenID Connect with PKCE, state and nonce; the ID
  token's signature (provider keys only, never HS* or none), issuer, audience, times and nonce are
  checked. The provider decides the role at every sign-in, a provider account is never joined to
  an existing local account, and its sessions end a fixed time after the sign-in. The client
  secret is sealed in a private table; tokens are not stored. Password sign-in can be limited to the
  first admin, who always keeps it as the emergency way in.
- Stored secrets (the LLM gateway's API key, single sign-on client secrets) are sealed with
  AES-256-GCM before they reach the database, with a key from `YADVAULT_SECRET_KEY` or a key file
  in the data folder; see [encryption.md](encryption.md), which also covers encrypting the disk.
- Links into the app never act on their own: a link to the Ask page fills in the question, and the
  user sends it.
- Every response carries `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`,
  `X-Frame-Options: DENY` and a Content-Security-Policy that allows only the app's own origin
  (no external scripts, images or connections, so a link or image in a message or an answer
  cannot make the browser call out). The API docs page is the one exception (see docs/api.md).
- API and MCP tokens are random, shown once, stored as SHA-256 hashes, scoped (`api`, `mcp`,
  `admin`) and revocable. The MCP server also limits request size and calls per minute, and
  writes an audit row per call (time, token, tool, parameters, row count; never content).

## License keys

A license key is checked on the server, offline; the app never contacts anyone about it. A key
saved in Settings is kept in a private table, which the AI tools' database role cannot read. The
free version's limits are enforced by the API, not by the browser: hidden conversations, people
and records are left out of every list, search and AI tool result, and opening one directly
answers 402.

## The AI tools

- Tool results reach the model wrapped in a notice that they are archive data written by other
  people, never instructions; the system prompt repeats that content is not instructions.
- Every tool is read-only. The two optional write tools (notes and tags) and the read-only SQL
  tool are off until an admin enables them in Settings, and they never touch messages. In Ask they
  are available to admins only; over MCP, notes and tags need a token with the `write` scope and
  the SQL tool one with the `admin` scope.
- In the compose deployment the tools run with a separate database role (`yadvault_ro`) that can
  `SELECT` the archive tables and nothing else: no accounts, sessions, tokens, settings, audit log
  or Ask history. `yadvault db upgrade` sets these privileges after every migration. Audit rows
  and optional notes go through the app's own connection.
- The SQL tool is confined by the database, not by inspecting the query: it runs the model's
  `SELECT` as `yadvault_sql`, a role that can read only the `v_*` views, in a read-only
  transaction with a 10-second limit, and it refuses to run at all on a connection whose role
  could read more than the archive (the superuser, or no read-only role configured).
- No AI feature acts on content: the model cannot delete, send, label or change anything.

## Containers

Images are multi-stage, built from pinned base images, and run as a non-root user with a
read-only root filesystem, all capabilities dropped and `no-new-privileges`. The database,
worker and embeddings service sit on a network with no route to the outside. Memory limits apply
to every service. Health checks and restart policies keep things running; migrations run on
start under a lock.

## Logs

Request logs carry method, path, status and duration, never query strings (search terms are
content) or bodies. Worker logs carry job ids and stages. Error logs can include exception
messages from the database driver or the model client; those do not contain message text by
construction, but review them before sharing.

## Backups

`scripts/backup.sh` and `yadvault backup` encrypt the dump with [age](https://age-encryption.org)
to a public key you provide. Keep the matching identity (secret key) outside the server. A backup
without the key is unreadable; a key without the backup is useless. Test a restore once
(`scripts/restore.sh`) so you know the pair works. Backups include the key file that opens the
stored secrets (not `YADVAULT_SECRET_KEY`, which you keep yourself).

## What you still have to do

- **Keep the ports on your LAN.** The services bind to `BIND_ADDRESS` (default: every
  interface of the host). Do not forward 8000, 8765 or 3000 on your router. If other devices on
  the LAN are not trusted, bind to `127.0.0.1` and use SSH port forwarding, or restrict the
  ports with the host firewall to `LAN_SUBNET` (see [operations.md](operations.md)).
- **Use HTTPS on the LAN** if you log in from other devices: `docker-compose.https.yml` runs
  Caddy with a local certificate authority or a Let's Encrypt certificate and closes the
  plain-HTTP port 8000 ([https.md](https.md)).
- **Encrypt the disk.** The database and data volumes are plain files on the host. Put Docker's
  data directory on an encrypted volume (LUKS on Linux, FileVault on macOS, BitLocker on
  Windows, an encrypted dataset or shared folder on a NAS) so a stolen disk does not give the
  archive away; [encryption.md](encryption.md) lists the options per host.
- **Keep the public-profile add-on off** unless you accept the risks described in Settings and
  in [operations.md](operations.md#public-profiles-add-on). It never logs in;
  its service downloads only from Instagram's media servers (host-checked, also after
  redirects); the app re-encodes every picture and serves posts and videos under a sandboxing
  Content-Security-Policy; bios and captions are shown as plain text and links open only as
  http(s).
- **Update.** `docker compose pull && docker compose up -d` picks up fixes; CI scans the images
  for known vulnerabilities on every change.
