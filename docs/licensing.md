# Free version and YadVault Pro

YadVault runs as the free version until it has a license key. A key turns YadVault Pro on at
once: nothing has to be imported again, and nothing is deleted when a license ends.

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

Every installation has its own ID, shown in Settings → License (with a copy button) and by
`docker compose exec app yadvault license id`. Give it when you ask for a trial or buy Pro: the
key is made for this installation and works only here (the "Get YadVault Pro" button passes the
ID to the shop for you). The ID stays the same through restarts, updates and a restored backup,
so moving to a new server with your backup keeps your license. A brand-new installation (a new,
empty database) gets a new ID and needs its own key.

## Entering a license key

You receive the key by email; paste it as it is. Case does not matter, and dashes and spaces are
ignored. Use one of these:

1. **Settings → License** (admins): paste the key, **Check** shows what it unlocks, **Activate**
   saves it. **Remove the key** goes back to the free version.
2. **`.env`** on the server: `YADVAULT_LICENSE_KEY=<key>`, then `docker compose up -d`. Or put the
   key in a file and set `YADVAULT_LICENSE_FILE` to its path inside the containers (a Docker
   secret, for example). A key set here wins over Settings, and Settings → License shows it
   without letting anyone change it in the browser.
3. **The command line:**

   ```bash
   docker compose exec app yadvault license set <key>
   ```

   `yadvault license status` shows the license and what the free version hides right now;
   `yadvault license remove` removes a key saved in Settings.

### Checking a key before you activate it

**Check** in Settings → License, or on the server:

```bash
docker compose exec app yadvault license check <key>
```

Both run the same verification as the product itself and print the license number, the dates,
the number of accounts and whether the key is for this installation only, or why the key is not
valid ("made for another installation" means the key was issued for a different installation ID).
Nothing is saved.

## Dates, reminders and renewal

- From 30 days before the end date, admins see a reminder at the top of every page.
- After the end date, Pro keeps working for a grace period of 14 days. Trial (proof of value)
  licenses have no grace period.
- After that the free version runs. Everything imported while Pro was on stays visible,
  including in search and Insights; the free limits apply only to what is imported later. Pro
  features turn off, and accounts other than the first cannot sign in. They are kept and work
  again with a new key.
- A license that starts in the future shows its start date; the free version runs until then.
- To renew, enter the new key. It replaces the old one.

YadVault remembers the latest date it has seen. Setting the server's clock back does not extend a
license.

## Accounts

The free version has one account: the admin created in the setup wizard. With Pro you add more
accounts in Settings → Users. Each license has a number of accounts, shown in Settings →
License ("No limit" for most licenses). When there are more accounts than that, the newest ones
cannot sign in until accounts are removed or the license allows more.

## Your license stays on your server

The key is checked on your server, offline: there is no activation server, and YadVault never
contacts anyone about your license. A key holds no name, no email address and nothing else about
your server.
