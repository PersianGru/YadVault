# HTTP API, Ask and MCP

The API is documented in the app: **API documentation** in the user menu, or `/api-docs`
(`/api/docs` leads there). It shows every endpoint with what it takes and answers, which ones need
an admin or YadVault Pro, and *Try it out* sends real requests as you (with your session and its
CSRF header, or with an API token entered under *Authorize*). Swagger UI is bundled with the app,
so nothing loads from elsewhere, and the page never sends the description to the public validator.
The description itself, `/api/openapi.json`, is only for signed-in users (a session or an API
token). This page covers what the description cannot say: authentication, the Ask stream, and how
to connect an MCP client.

## Authentication

- First run: `GET /api/setup/status` says `needs_setup`; `POST /api/setup` creates the admin
  account (optionally with the LLM gateway: `llm_url`, `llm_api_key`, `llm_model`) and signs it in.
- `POST /api/auth/login` sets an HttpOnly session cookie (`yadvault_session`, 30 days, sliding).
  Logins are rate-limited per address and per username. `POST /api/auth/logout` ends the session.
- Every `/api/*` route except the probes, the setup wizard and the login needs a session, or a
  bearer token with the `api` scope (`Authorization: Bearer iga_...`).
- State-changing requests from a session must send the header `X-CSRF-Token` with the value from
  `GET /api/me` (derived from the session cookie, never stored).
- Roles: `admin` can change things; `readonly` can read everything and use Ask with read-only
  tools. Admin-only routes answer `403` otherwise.
- Passwords are hashed with argon2id; sessions and API tokens are stored as SHA-256 hashes of the
  values the client holds, so a copy of the database cannot be replayed as a login.
- Login is limited per client address (10 attempts in 5 minutes) and per account (20 an hour;
  every spelling of a username counts against the same account); a successful login does not
  reset either. Checking the current password on a password change is limited too.
- `POST /api/setup` (first run only) needs the one-time `setup_code` from the server log or
  `YADVAULT_SETUP_CODE`.

## Conversations as PDF

`GET /api/threads/{id}/pdf` answers the conversation as a PDF file (`date_from`, `date_to`, `tz`,
`photos`, `added`; `evidence=true` for an evidence copy, Pro). `X-Content-SHA256` is the checksum
of the file and `X-Evidence-Manifest-SHA256` that of the evidence copy's list of messages; every
PDF made is written to the audit log (`thread.pdf`). `GET /api/threads/{id}/pdf/estimate` says how
many messages and photos it would hold and whether that is over the 5,000 messages per document
(`413` from the PDF route). The checksums are described in [evidence.md](evidence.md).

## Conversations from Messenger

Conversations imported from a Facebook Messenger export sit beside the Instagram ones:
`platform` is `instagram` or `messenger` in `GET /api/threads` and `GET /api/threads/{id}`, the
list takes `platform=` as a filter and answers `platforms` (conversations per app). Their keys
start with `fb:`, so a Messenger conversation never merges with an Instagram one. Messenger names
people and nothing else, so each Messenger friend is one person of kind `unresolved` until it is
linked with an account in the review.

## Tags

One set of tags serves people and conversations (`/api/labels`). `PUT /api/people/{id}/labels`
and `PUT /api/threads/{id}/labels` replace a person's or a conversation's tags; a person and their
1:1 conversations share every change (the answers say how many `conversations` or `people` were
updated with them). For a group conversation, `"members": true` also adds the newly added tags to
its members. `POST /api/labels/{id}/threads` adds or removes a tag on many conversations at once,
with the same sharing.

## License and the free version

`GET /api/license` (also inside `GET /api/me` as `license`) returns the license: `edition`
(`free` or `pro`), `status` (`free`, `invalid`, `not_started`, `active`, `grace`, `expired`), the
dates, the number of accounts, `installation_id` (this installation's ID) and `bound` (the key
works on this installation only), `limits` (the free version's limits, `null` with Pro) and `locked`
(how many conversations, people and records the free version hides right now). Admins use
`POST /api/license/check` to verify a key without saving it, `PUT /api/license` with `{"key":
"..."}` to save it (409 while `YADVAULT_LICENSE_KEY` is set, 422 for an invalid key) and
`DELETE /api/license` to remove it.

A request for something the free version does not include answers `402 Payment Required` with
the header `X-YadVault-Pro` naming the feature (`ask`, `semantic`, `mcp`, `tokens`, `export`,
`notes`, `accounts`, `insights`, `conversations`, `people`, `records`). Lists leave hidden items
out and report how many in `locked`; semantic and hybrid search fall back to keyword search with
`pro_required: "semantic"`. Bearer tokens and the MCP server need Pro.

## Single sign-on

`GET /api/auth/sso/providers` lists the providers of the sign-in page (none without Pro). The
browser opens `GET /api/auth/sso/<provider>/start?next=/path`, which redirects to the provider
and sets a ten-minute cookie (`yadvault_sso`, path `/api/auth/sso`); the provider sends it back
to `GET /api/auth/sso/<provider>/callback`, which signs the person in and redirects to `next`
(a path of this site only) or to `/login?sso_error=<reason>`. Admins manage providers under
`/api/settings/sso` (`GET`; `POST /providers`, `PUT` and `DELETE /providers/{id}`,
`POST /providers/{id}/check`, `PUT /options`), and `start?test=true` runs a test sign-in whose
outcome `GET /api/settings/sso/test-result` returns. [docs/sso.md](sso.md) has the setup.

## Ask

`POST /api/ask/conversations/{id}/messages` with `{"question": "..."}` answers with a
`text/event-stream`. Events (`data:` lines with JSON):

| type | payload |
|---|---|
| `start` | `run_id` (for `POST /api/ask/runs/{run_id}/stop`), `model` |
| `step` | one tool call: `tool`, `arguments`, `summary`, `rows`, `ms`, `ok` |
| `token` | a piece of the answer text |
| `retract` | discard the text streamed so far (the model decided to call a tool after all) |
| `artifact` | a chart or card: `type` (`bar`, `timeline`, `person`, `table`), `rows`, `tool` |
| `note` | an engine note, e.g. the switch to the JSON tool protocol |
| `error` | the model or the engine failed |
| `done` | `answer`, `citations`, `artifacts`, `trace`, `steps`, `seconds`, `stopped_reason` |
| `saved` | ids of the stored user and assistant messages |

Citations are `[m:<message id>]`, `[u:<user-added message id>]`, `[p:<person id>]`,
`[t:<thread id>]`, `[r:<record id>]` in the answer text and resolved in `citations` (with the
thread and timestamp to open the conversation at that message). `regenerate: true` re-asks the
last question; `replace_last: true` edits it. Conversations can carry a scope (`person_id`,
`thread_id`, `date_from`, `date_to`) that tools default to.

The engine calls the LLM gateway's OpenAI-compatible `<API root>/chat/completions` (LiteLLM, Ollama,
vLLM or Open WebUI's `/api`) with the tool definitions. Models without
native tool calling get a JSON protocol in the prompt (`ask.tool_mode`: `auto`, `native`, `json`).
Limits: `ask.max_steps` tool calls and `ask.max_seconds` per question; tool results are capped
at 200 rows and 24 kB each. Tool results reach the model wrapped as untrusted archive data; the
tools are read-only; the optional note and tag tools need `ENABLE_ANNOTATIONS=true`, the SQL
tool `ENABLE_SQL_TOOL=true` (read-only views, 10 s, 200 rows).

## Account insights

Exports are compared in the order they were made, not the order they were imported: every import
notes when its export was made (`export_at`, the newest moment in its content). Instagram does not
record when someone unfollowed, so each change carries its window: it happened between
`window_from` and `window_to`, the dates the two exports were made.

`GET /api/insights/connections` returns the newest follower and following totals, every export
that carried those lists, and what changed between the newest export and the one before it
(`batch_id` picks another export). `change` is `added`, `removed`, `refollowed` (unfollowed and
followed again in between: the follow date moved, `prev_since_at` holds the old one) or
`reappeared` (back with the old follow date: the account was deactivated or hidden, it did not
unfollow). `pairs` names the exports compared; `newer_list_from` / `older_list_from` are set when a
list looks limited to a date range (an export made for "the last year"), whose older follows are
then not compared. `GET /api/insights/on-and-off?relation=follower|following` lists the accounts
that left and came back at least once across all exports, each with its story (`events`: left,
back, left_and_back, away, visible_again, followed). `GET /api/insights/my-unfollows?date_from=&date_to=`
lists the accounts you unfollowed: exact times where the export lists them as recently unfollowed
(`exact_since` says from when), otherwise the window. `GET /api/insights/people/{id}` is one
person's follow history. `GET /api/insights/not-following-back?direction=they_dont|i_dont` pages
through people you follow who do not follow you, or the reverse. `GET /api/insights/following-timeline`
buckets follow dates. `GET /api/insights/activity?kind=&date_from=&date_to=` summarises likes,
comments, saves, searches and logins. The tools `connection_changes`, `follow_history`,
`my_unfollows`, `not_following_back` and `account_activity` expose the same data to Ask and MCP.

## Notifications and the watch folder

`GET /api/notifications` lists the latest notifications, each `unread` for the signed-in user,
and how many are unread; `POST /api/notifications/seen` marks them read for that user. Every
finished import leaves one (`kind: import`) with new rows and who unfollowed you or started to
(`data.unfollowed_you`, `data.new_followers`, `data.counts`); a watched export that cannot be
imported leaves a `watch_error`. With `notify.webhook_url` set (sealed, masked in Settings), the
same goes to that address with counts only: JSON (`{"title", "message", ...counts}`) or, with
`notify.webhook_format: text`, a plain message with a `Title` header (ntfy). `POST
/api/notifications/test` (admins) sends a test and says how the webhook answered.
`GET /api/watch` and `POST /api/watch/scan` (admins) show and run the watch folder
(`watch.enabled`, `watch.dir`, `watch.delete_after_import`): the worker looks every 30 seconds
and imports an export once it has not changed for a minute, never twice.

## AI extras (Pro)

Through the owner's LLM gateway, with the models chosen in Settings → Ask (`ai.transcribe_model`,
`ai.vision_model`, `ai.summary_model`; the last defaults to the Ask model). `POST /api/ai/media`
with `task: transcribe` writes out every copied voice message (the gateway's OpenAI-style
`/audio/transcriptions`), `task: caption` describes every copied photo in a sentence (a chat
model that sees pictures, the photo sent as a 1024 px JPEG); both run as an `ai_media` job a few
files per run (`retry_failed: true` tries the failed ones again; five failures in a row stop it).
`GET /api/ai/status` shows the models and how far they got. Transcripts appear with the
attachments (`media_transcript`); `GET /api/media?q=` finds photos and voice messages by their
description or text. `POST /api/threads/{id}/summaries` with an optional `date_from`/`date_to`
summarises the newest messages of that stretch that fit (about 24,000 characters; marked as data
for the model) and keeps the result; `GET` lists them. The audio, pictures and messages go to
the gateway: choose local models.

## On this day

`GET /api/on-this-day?month=&day=` (today when left out) is that calendar day in earlier years,
newest first: messages and the conversations they were in, the first message of the busiest one
(`highlight`, up to 280 characters; open it with `/threads/{thread_id}?m={id}`), photos copied
from that day, who started to follow you, and how much you posted. Conversations the free version
hides are left out, and so are photos outside conversations (the gallery is Pro).

## Your year

`GET /api/recap?year=&tz=` is one year in numbers: messages sent and received, people and
conversations (and how many were new), days with messages and the longest streak, the busiest
day, messages by month and weekday, the messages you sent by hour (in `tz`, an IANA zone, per
day so summer time is followed), the people and the conversation you wrote with most, the
reactions you gave most and how often others reacted to you, what you sent (photos, videos,
links...), follows that started that year and account activity. Without `year` it answers for
the newest year with data; `years` lists them all. Counts, dates and names only, never message
text; the page draws its shareable picture in the browser (first names only when asked).

## Photos, videos and voice messages

`POST /api/imports/preflight` returns `media` (files and bytes by origin and by kind) when the
export carries them; `POST /api/imports` takes `media: ["photo", "video", "audio"]` (any subset)
and queues a `media` job after the import, which copies those files into the data folder
(`media/`, one copy per distinct content) and links each one to its conversation.
`POST /api/imports/{batch_id}/media` with `kinds` copies them later, while the export is still on
the server (`409` when it is gone or a media job is running).

Message attachments carry `media_id`, `media_kind`, `media_ext` and `media_bytes` once copied.
`GET /api/media/{id}` returns the file (only from a fixed list of types, with
`Content-Security-Policy: default-src 'none'; sandbox`) and `GET /api/media/{id}/thumb` a small
WebP of a photo; a conversation's media follow the conversation's visibility. `GET /api/media`
(Pro) is the gallery, newest first, filtered by `origin` (message, post, story, reel, profile,
other), `kind`, `person_id`, `thread_id` and `year`; `GET /api/media/summary` counts files and
bytes by origin and kind.

## Storage

`GET /api/storage` (admins) reports free disk space, the database by area and by its biggest
tables, the data folder (copied media, thumbnails, profile pictures, added files, uploads), every
upload still on disk with why it is left over (`kept`, `abandoned`, `not_imported`,
`failed_import`, `unknown`) or in use, and the space each cleanup task would give back.
`GET /api/storage/conversations?kind=direct|group` and `GET /api/storage/people` rank
conversations and people by message text plus copied media (names the free version hides stay
hidden); `GET /api/people/{id}/storage` is one person's share: your one-to-one conversations with
them, the groups you share, the media they sent anywhere and their profile picture.

`POST /api/storage/cleanup` with `task` queues a `cleanup` job and writes an audit log entry:
`thumbnails`, `uploads` (`params.upload_ids` to pick some), `rolled_back_media`, `tidy`
(half-copied media, unlisted media files, unused profile pictures), `media` (`params.kinds`,
`origins`, `thread_ids` or `person_id`; the messages stay), `semantic_index` (drops the vectors
and gives the space back at once; the next embedding run builds them again) and `database`
(VACUUM ANALYZE). Imported uploads stay for `retention.delete_uploads_after_days` (Settings →
Import, 7 by default; `expires_at` in the list) so their media can still be copied, unless the
import kept them (`kept`); the worker deletes them when the time is up.
`GET /api/media?person_id=` is the gallery for one person: your one-to-one conversations with
them and what they sent anywhere. Follow the job with
`GET /api/jobs/{id}`; its `progress.result` says what was freed. Rolling back an import removes
the media copied for it by itself.

## Public profiles (add-on)

Off by default, never an Instagram login; needs the fetcher service (compose profile `avatars`).
`GET /api/profiles/status` (admins) reports whether the add-on is on and the service deployed,
the queue by status (`queued`, `done`, `private`, `missing`, `failed`), the pace
(`rate.interval_seconds`) and any pause after a block (`paused`, `rate.paused_until`), the cache
against its cap, and how long the queue takes. `POST /api/profiles/estimate` with `person_ids` or
`everyone: true` answers how many people, how long and how much space before anything starts;
`POST /api/profiles/queue` with the same queues them (people you talk to most first) and starts
the one `profile_sync` job, which looks up one person per run and puts itself back with
`run_after` for its pace. `POST /api/profiles/pause`, `POST /api/profiles/resume` and
`DELETE /api/profiles/queue` control it; `POST /api/people/{id}/profile/sync` puts one person
first. `GET /api/people/{id}/profile` is what was found (public details and posts, newest
first; the free version shows the latest 3 and says `limited`) plus `enabled` and `deployed`, so
the page offers a look-up only when one can run; the queue and sync calls answer `409` with what
to set when the add-on is off or no service is deployed. `GET /api/profile-posts/{id}/image`
and `/video` serve the cached files under the same sandboxing Content-Security-Policy as media.
Settings: `profiles.videos`, `profiles.storage_cap_gb`, `profiles.refresh_days`,
`profiles.min_messages` (and `avatar_fetch.enabled`, the switch). Bios, captions and links come
from Instagram: treat them as untrusted text.

## What Instagram knows

`GET /api/insights/privacy` reads the export's account data back as a report: headlines (topics
Instagram thinks interest you, advertisers using your activity or information, ads and posts
seen and ads clicked, logins and the addresses they came from, devices, searches, the fields of
your personal information, an imprecise last known place), each area (ads, logins and devices,
account details, activity, lists, your content) by kind with counts, first and last dates and up
to six short examples (leaving out what the free version hides), and how many files of the
newest export the archive does not read yet.

## Profile pictures from the fetcher

`POST /api/people/{id}/avatar/fetch` asks the optional avatar-fetcher service for one person's
picture and profile facts (full name, private flag, numeric user id, whether the username still
exists); `POST /api/avatars/fetch-batch` with `person_ids` queues a paced `avatar_fetch` job,
capped by `Settings → Profile pictures`. Both answer `409` while the fetcher is off or not
deployed and `429` when the service hit a rate limit or a login wall. A username that no longer
exists marks the person `status = missing` ("possibly renamed or deleted" in the UI).

## Operations endpoints and commands

`GET /api/health` (process up) and `GET /api/ready` (database reachable) back the container
health checks. `yadvault check [--wait N]` validates the configuration, `yadvault version`
prints the version, `yadvault backup` and `yadvault restore` handle encrypted backups (see
docs/operations.md).

## MCP server

The app serves the same tools over Streamable HTTP at `/mcp`, at the address and port of the web
UI and the API (`https://<server>/mcp` with HTTPS on, `http://<server>:8000/mcp` without): nothing
else to start, and one address for a reverse proxy. Create a token in Settings (scope `mcp`) and
send it as `Authorization: Bearer <token>`. Every call is written to the audit log (time, token, tool,
parameters, row count; never content); requests are limited to 256 kB and 120 calls per minute
per token.

Open WebUI: in *Admin Settings → External Tools* add a connection of type MCP (Streamable HTTP)
with the URL above and the bearer token, then enable the tools for your model. On versions
without native MCP support, run [mcpo](https://github.com/open-webui/mcpo) in front of the
server and add it as an OpenAPI tool server instead. Small models need *native function
calling* enabled in the model's advanced parameters to use tools reliably.
