# Conversations as PDF, and evidence copies

Every conversation has **Save as PDF** in its header: the whole conversation or some days of it,
with the date and time of every message (in your time zone), the photos that were copied to the
archive, and, if you want, the messages you added in YadVault (marked as such). Up to 5,000
messages go in one PDF; choose some days for longer conversations. Text in any script is drawn
with the fonts of the server (the Docker image ships Noto Sans for most scripts, Noto Sans CJK,
Noto Color Emoji and DejaVu Sans); a character no font has is written as `[U+XXXX]` rather than
left out. More fonts: put .ttf, .otf or .ttc files in a folder and set `YADVAULT_PDF_FONTS_DIR`
to it; `docker compose exec app python -m yadvault.pdf --list` shows the fonts found.

## Evidence copies (YadVault Pro)

An **evidence copy** is for a dispute, a complaint or a report of harassment: someone who was not
there can check its messages against the export the platform sent. The copy lists a checksum for
every message, and the check prints what the export says for each, to compare with the pages
(see [what a check shows](#what-a-check-shows-and-what-it-does-not)).

- Every message shows its exact time in UTC to the millisecond (as the export has it), the file and
  position it came from in the export (for example `inbox/<conversation>/message_1.json item 17`),
  and a SHA-256 checksum of its content.
- A copied photo, video or voice message shows the SHA-256 of its file.
- The checksums are attached to the PDF as `manifest.json` (PDF readers list it under
  attachments), with a checksum of the whole list in the document, its metadata and every page's
  footer.
- Messages added in YadVault are never in an evidence copy. AI transcripts are left out too.
- The last page says how to check the copy. The checksum of the PDF file and of the list are shown
  after the download and written to the audit log with who made it and when.

### What is hashed

For each message, these fields are written as JSON with the keys sorted, no spaces, UTF-8 (not
escaped), and hashed with SHA-256:

| Key | Value |
|---|---|
| `thread` | the conversation key: the number in the conversation's folder name in the export (Messenger: `fb:` before it; an encrypted chat: `fb:h:` and a hash of its file name and participants) |
| `time_ms` | the time in milliseconds since 1970 (UTC), as exported |
| `sender` | the sender's name as exported |
| `text` | the text (`""` when there is none) |
| `attachments` | the paths of its photos, videos, voice messages and files, in the export's order |
| `link`, `share_text` | a shared post's link and text (`""` when there is none) |
| `unsent` | `true` for an unsent message |
| `call_seconds` | the length of a call, or `null` |

Reactions are shown in the PDF for context but are not hashed (a later export can differ there).
The checksum of the list is SHA-256 over the line `yadvault-evidence/1`, the conversation key and
the message checksums, each followed by a line break, in the order of the document.

Example: the message from `Ada Example` at `1700000000123` with the text `Hello ✨`, one photo
`messages/inbox/ada_1234567890123456/photos/x.jpg` and a shared link `https://example.com/p/1` with
the text `a post`, in conversation `1234567890123456`, is written as

```json
{"attachments":["messages/inbox/ada_1234567890123456/photos/x.jpg"],"call_seconds":null,"link":"https://example.com/p/1","sender":"Ada Example","share_text":"a post","text":"Hello ✨","thread":"1234567890123456","time_ms":1700000000123,"unsent":false}
```

and its checksum is `39f5767c45205d2239d26e5d75894dadceee583fffaf0a9b5424e785def1a511`.

### Checking a copy

You need the export the messages came from: the zip files (or the unzipped folder) that Instagram
or Facebook sent. On the server, or wherever YadVault is installed:

```
yadvault evidence verify conversation-...-evidence.pdf the-export.zip
docker compose exec app yadvault evidence verify /data/copy.pdf /data/import/export-part1.zip /data/import/export-part2.zip
```

It finds the conversation in the export and computes again the checksum of every message the
copy's `manifest.json` lists. For each it prints what the export says (the time in UTC, the sender
as exported, the text, the files and a shared link) or that the message is not in the export, then
how many are there unchanged (exit code 0 when all are and the list is whole). Text is printed on one
line, with line breaks, control characters and long runs of spaces written out, so nothing in a
message can redraw the terminal. `--json` prints the same as JSON, in ASCII only: any other
character is written as a `\u` escape, which a JSON parser reads back exactly. It takes the
`manifest.json` saved from the PDF as well. Without YadVault, the table above is enough to write
the same check in a few lines of any language.

### What a check shows, and what it does not

- It shows that each message the manifest lists is in that export with the same time, sender,
  text, attachments and shared link.
- It does **not** read the pages. The text drawn on a page can be changed in a PDF editor, and a
  made-up PDF can carry a genuine manifest, so compare the pages with the listing: a message that
  reads differently there, or is not in it, is not the export's. The page shows the sender's
  display name, the listing the name as exported; they can differ.
- Photos and other files are not compared: the listing names each file's path in the export, to
  open there and compare with the page.
- The checksum of the list shows only that the list is whole as written. Anyone who changes the
  list can compute it again, so it is not a tamper check.
- It does not show that the copy holds every message of the conversation in its range: messages
  can be left out of a copy.
- Reactions, and the local times in the headings, are drawn for context and are not covered.

The export itself comes from the platform (it can be requested again from the account), so the
messages can be traced to it; YadVault does not sign anything with a key of its own, because a key
on your own server would prove nothing to someone else.

From the command line, `yadvault evidence pdf <conversation id> --out copy.pdf [--evidence]`
makes the same PDF on the server (`--from`, `--to`, `--tz`, `--no-photos`).
