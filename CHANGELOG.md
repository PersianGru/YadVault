# Changelog

Releases of YadVault and of the deployment files in this repository. Each release pins the
images of that version (`YADVAULT_VERSION` in `.env.example`); versions follow
[Semantic Versioning](https://semver.org/), and breaking changes are called out here.

## 0.2.0

- **Breaking: the MCP server is part of the app.** It answers at `/mcp` on the address and port
  of the web UI and the API (`https://<server>/mcp` with HTTPS on), so its bearer tokens travel
  encrypted; YadVault Pro and a token with the `mcp` scope are still needed. The `mcp` profile and
  service, port 8765 (`MCP_PORT`, `MCP_MEMORY_LIMIT`) and `yadvault mcp` are gone: point MCP
  clients (Open WebUI and others) at the new address and drop `mcp` from `COMPOSE_PROFILES`.
- **Trial:** "Start a 14-day trial" opens the order page with the installation ID; the key comes
  by email once the request is approved.
- **Evidence copies:** `yadvault evidence verify` says what it checks and prints what the export
  says for every listed message, to compare with the pages; `--json` prints ASCII only.
- **Fixes:** backup files are readable by their owner only; an import of your own added messages
  writes attachments only inside the attachments folder; links in Ask answers stay on this site.

## 0.1.0

The first public release.

- **Import** the official Instagram data export (zip parts or folders, millions of messages,
  resumable) and Facebook Messenger exports; re-importing a newer export adds only what is new.
- **Browse and search** conversations, people and every other kind of record, by keyword and (Pro)
  by meaning, in any language; tags and messages you add yourself, kept apart from the originals.
- **Insights:** who followed or unfollowed you and when, follow history per person, activity over
  time; "On this day", "Your year" and "What Instagram knows about you".
- **Ask** (Pro): questions in plain language through your own OpenAI-compatible LLM gateway, with
  charts and citations; an MCP server for other clients.
- **Media:** photos, videos and voice messages in conversations; the gallery (Pro).
- **Save a conversation as PDF**; evidence copies with checksums (Pro).
- **Backups** in Settings, encrypted with age, now or on a schedule (free).
- **Unfollower tracker:** a watch folder that imports new exports on its own.
- **Public profiles (add-on, off by default):** looks people up the way anyone can without logging
  in.
- **Single sign-on** with Entra ID or Okta (Pro); HTTPS on the LAN with Caddy.
- **Install templates** for Synology, TrueNAS SCALE, Unraid, CasaOS and umbrelOS.
- **Free version and YadVault Pro:** see [docs/licensing.md](docs/licensing.md).
