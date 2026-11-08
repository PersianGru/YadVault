# Free version and YadVault Pro

YadVault runs as the free version until it has a license. A license file turns YadVault Pro on
at once: nothing has to be imported again, and nothing is deleted when a license ends.

## What each includes

| | Free | Pro |
|---|---|---|
| Import, resume, roll back, re-import newer exports | yes | yes |
| Conversations | the 200 most recently active | all |
| People | 200 | all |
| Records (likes, comments, logins, ...) | the 5 newest of each kind | all |
| Keyword search, tags, added messages, the review queue | yes | yes |
| Insights | the summary and the first 10 rows of each list (changes, on and off, your unfollows, not following back) | everything, including follows over time and monthly activity |
| Accounts | one: the admin created in the setup wizard | more accounts, admin and read-only roles, single sign-on with Entra ID or Okta ([sso.md](sso.md)) |
| Ask (answers from an AI model) | no | yes |
| Semantic search (search by meaning) | no | yes |
| The MCP server, API and MCP tokens | no | yes |
| Notes on people | no | yes |
| Exports (Settings → Your data, identity decisions) | no | yes |
| Backups (`scripts/backup.sh`, `yadvault backup`) | yes | yes |
| Watch folder (the unfollower tracker) | a folder on the server | also a shared folder on your NAS, PC or Mac over the network |
| Bulk sync (the add-on that looks people up on Instagram) | no | yes |

Features the free version does not include stay visible, grayed out with a **Pro** label, so you
can see what they are. The limits are enforced by the server: what the free version hides is
never sent to the browser, the API or the AI tools.

### Beyond the free limits

The free version hides, never deletes. The lists say how many more items the archive holds, and
counts on the dashboard and in Insights stay complete. What stays visible:

- **Conversations:** the 200 with the most recent messages.
- **People:** the people in those conversations first, then others you have messaged, then your
  followers and the accounts you follow, newest first, up to 200 in all. You never count.
- **Records:** the 5 newest of each kind.

Search, the dashboard, Insights and the review queue only use what is visible. Opening a hidden
conversation or person by its address shows what Pro would unlock instead.

## Your installation ID

Every installation has its own ID, 38 digits shown in groups of five in Settings → License (with
a copy button) and by `docker compose exec app yadvault license id`. Give it when you ask for a
trial or buy Pro: the license is made for this installation on this server and works only there
(the "Get YadVault Pro" button passes the ID to the shop for you). The ID stays the same through
restarts and updates.

The ID is tied to the server. When the database moves to another server (a restored backup, a
copied database) the installation gets a new ID there and needs a new license file for it; ask
support, giving both IDs. A brand-new installation also gets a new ID and needs its own license.

### Machine ID

On a Linux server that has `/etc/machine-id` (`cat /etc/machine-id` prints 32 hex characters),
tie the ID to the server itself: add the file `docker-compose.machine-id.yml` in `.env`

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.machine-id.yml
```

and run `docker compose up -d`. Without it, YadVault ties the ID to its data folder (a value kept
there and left out of backups). Settings → License says which one is used. Do this before you
order: switching later gives the installation a new ID, which needs a new license file.

## Entering your license

After you order (or when your trial is approved) you receive a **license key** (`YDV-XXXXX-…`)
by email. The easiest way: paste the key in **Settings → License** and press **Activate**.
YadVault sends the key, your installation ID and a one-way code of the machine to the 21CL License Hub
once, over HTTPS, and receives your **license file**, which it checks and saves. This is the only
time YadVault contacts anyone about your license; after that it runs offline. The same works on
the command line: `docker compose exec app yadvault license set YDV-XXXXX-…`.

A server without internet uses the license file itself. It may be in the email and on your order
page; otherwise `docker compose exec app yadvault license request YDV-XXXXX-…` prints an
**activation request code**: paste it on the 21CL License Hub's offline activation page from any
device with internet, and you get the file. It is a short text file that looks like this:

```text
-----BEGIN 21CEL LICENSE-----
Product: YadVault (yadvault)
Licensed-To: ...
Expires: ...

eyJhbGciOiJFZERTQSIs...
-----END 21CEL LICENSE-----
```

Use the whole file, as it is. A license key from before license files keeps working until it
ends. Use one of these:

1. **Settings → License** (admins): paste the license key or the file, or **Open a license
   file**; **Check** shows what a file unlocks, **Activate** saves it (for a key, after fetching
   its file). **Remove the license** goes back to the free version.
2. **On the server:** save the file and set `YADVAULT_LICENSE_FILE` in `.env` to its path inside
   the containers (a Docker secret, for example), then `docker compose up -d`.
   (`YADVAULT_LICENSE_KEY` takes a key, or the long line of the file between its header and its
   last line.) A license set here wins over Settings, and Settings → License shows it without
   letting anyone change it in the browser.
3. **The command line**, with the file copied into the container or a key:

   ```bash
   docker compose exec app yadvault license set /path/to/yadvault-license.txt
   ```

   `yadvault license status` shows the license and what the free version hides right now;
   `yadvault license remove` removes a license saved in Settings.

### Checking a license before you activate it

**Check** in Settings → License, or on the server:

```bash
docker compose exec app yadvault license check /path/to/yadvault-license.txt
```

Both run the same verification as the product itself and print the license, the plan, the dates,
the number of accounts and whether it is for this installation only, or why it is not valid
("made for another installation" means it was issued for a different installation ID). Nothing
is saved.

### Messages from support

A license file can carry a short message from YadVault support, for example about a renewal.
Settings → License shows it; a warning is also shown to admins at the top of every page. Messages
are plain text. To change or remove one, support sends you a new license file.

## Dates, reminders and renewal

- From 30 days before the end date, admins see a reminder at the top of every page.
- After the end date, Pro keeps working for a grace period (14 days for most licenses; the
  license says how long). Trial licenses have no grace period.
- After that the free version runs. Everything imported while Pro was on stays visible,
  including in search and Insights; the free limits apply only to what is imported later. Pro
  features turn off, and accounts other than the first cannot sign in. They are kept and work
  again with a new license.
- A license that starts in the future shows its start date; the free version runs until then.
- To renew, enter the new license file you receive after each payment. It replaces the old one.

YadVault remembers the latest date it has seen. Setting the server's clock back does not extend a
license.

## Accounts

The free version has one account: the admin created in the setup wizard. With Pro you add more
accounts in Settings → Users. Each license has a number of accounts, shown in Settings →
License ("No limit" for most licenses). When there are more accounts than that, the newest ones
cannot sign in until accounts are removed or the license allows more.

## Your license stays on your server

The license is checked on your server, offline. YadVault contacts the 21CL License Hub only when
an admin activates a license key, once, to fetch the license file; there are no check-ins after
that, and a license file entered directly needs no internet at all. A license file holds the name on the license and, for
an installation-bound license, a one-way code of your installation ID; nothing else about your
server.
