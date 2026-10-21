# Encryption at rest

What YadVault encrypts by itself, what it leaves to the disk, and how to encrypt everything.

## What YadVault encrypts

| What | How |
|---|---|
| Stored secrets: the LLM gateway's API key, the client secret of each single sign-on provider | Sealed with AES-256-GCM before they reach the database (below) |
| Account passwords | Hashed with argon2id; the password itself is never stored |
| Sessions and API tokens | Only a SHA-256 hash of the random value is stored |
| Backups (`scripts/backup.sh`, `yadvault backup`) | Encrypted with [age](https://age-encryption.org) to your public key |
| Traffic between your browser and the server | HTTPS, when you turn it on ([https.md](https.md)) |

A copy of the database (a dump, a copied volume, a backup without its key) therefore reveals no
password, session, token, API key or client secret.

## What it does not encrypt, and why

The archive itself (messages, people, records, pictures) is stored as the database needs it to
search and sort: keyword search, typo-tolerant search and semantic search all read the text. If
the app encrypted these columns, search would stop working, and the key would still have to sit
on the same server to read anything, so it would protect little. What protects the archive at rest
is encrypting the disk it lives on.

## Encrypting everything: the disk

Disk encryption protects the database and the data volume when the machine is off, when a disk is
stolen or thrown away, and when a virtual machine's image is copied. Choose what fits the host:

| Host | How |
|---|---|
| Linux | LUKS (dm-crypt) on the partition that holds Docker's data (`/var/lib/docker`, or move the data root there), or a ZFS dataset with native encryption |
| Synology DSM | an encrypted shared folder or volume encryption (DSM 7.2 and later) for the folder where the containers keep their data |
| TrueNAS | an encrypted dataset for the app's storage |
| Unraid | an encrypted array or pool (XFS or Btrfs, encrypted) |
| Windows | BitLocker on the drive that holds Docker Desktop's data |
| macOS | FileVault |
| A virtual machine | encryption of the virtual disk by the hypervisor (Proxmox: LUKS or ZFS encryption on the storage; VMware: VM encryption), or LUKS inside the guest |

While the server runs, the disk is open: anyone who can sign in to the host can read the data.
That is what accounts, LAN-only ports ([operations.md](operations.md)) and HTTPS are for.
PostgreSQL itself has no built-in encryption of its files, so disk encryption is also the way to
encrypt the database.

## The key of the stored secrets

The key comes from one of two places:

- **A key file (the default).** The first time the app has a secret to store, it creates
  `keys/secret.key` in its data folder (`/data` in Docker), readable by the app's user only. Backups
  made with `scripts/backup.sh` or `yadvault backup` include it, and a restore puts it back, so
  restored secrets open again. Encrypt your backups (the default) because they hold the key.
- **`YADVAULT_SECRET_KEY`.** Set it in `.env` to keep the key out of the server's files and out of
  backups: `docker compose run --rm app yadvault secrets new-key` prints a new random key (32 bytes in
  base64; a passphrase of 16 or more characters works too). Every service reads it from `.env`.
  Keep it in your password manager: a restore on a new server needs it.

`yadvault secrets status` (in Docker: `docker compose exec app yadvault secrets status`) says which
key is in use and whether every stored secret opens with it. `yadvault check` warns about secrets
that do not.

**If the key is lost**, only the stored secrets are affected: the archive is not encrypted with it.
Settings shows "enter it again" next to the LLM gateway's API key and next to each single sign-on
provider whose client secret cannot be opened. Enter them again and they are sealed with the key in
use.

**To change the key**, run `yadvault secrets rotate`. With a key file it writes a new key file
(the old one stays next to it as `secret.key.old`; if anything stops halfway, `secret.key.new`
holds the new key). With `YADVAULT_SECRET_KEY`, put the new key in `YADVAULT_NEW_SECRET_KEY` first,
run the command, then make the new key `YADVAULT_SECRET_KEY` everywhere. Restart every service
afterwards.

Secrets saved by a version before sealing existed are sealed automatically by the next
`yadvault db upgrade`, which every container runs when it starts.

## How the sealing works

AES-256-GCM with a random 96-bit nonce per value. A sealed value reads
`enc:v1:<key id>:<nonce and ciphertext in base64>`; the key id is a short fingerprint of the key
that sealed it, so a value from another key is recognised instead of failing obscurely. Each value
is authenticated together with its place (for example `settings:llm.api_key`), so a sealed value
copied to another place does not open.
