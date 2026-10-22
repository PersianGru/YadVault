# HTTPS

HTTPS is optional. Without it the app serves plain HTTP on port 8000, which is fine on a computer
that only you use. Turn it on when other devices sign in over Wi-Fi or any network you do not
fully trust: otherwise passwords, session cookies and messages cross the network unencrypted.

HTTPS is served by [Caddy](https://caddyserver.com) in front of the app, from the override file
`docker-compose.https.yml`. Caddy listens on port 443, or the port you choose (below), and on
nothing else: there is no plain-HTTP port. The app's own port 8000 closes, so every request goes
through Caddy. A plain `http://` request on the HTTPS port (an old bookmark) is redirected to
`https://` on the same port.

## Turn it on

Add to `.env` on the server, then run `docker compose up -d`:

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.https.yml
HTTPS_MODE=local
CADDY_DOMAIN=192.168.1.10
```

Use the address you type in the browser for `CADDY_DOMAIN`: the server's IP address or a name.

**Another port:** when another service on the server already uses 443, publish Caddy on another
host port, for example the app's old port:

```bash
HTTPS_PORT=8000
```

The archive is then at `https://<server>:8000`. Browsers apply HSTS to every port of a name, so if
other plain-HTTP services share the server's name, also set `HSTS=off` (it does not matter for IP
addresses, which browsers never pin).
With `docker-compose.gateway.yml` as well, name all three files:
`COMPOSE_FILE=docker-compose.yml:docker-compose.gateway.yml:docker-compose.https.yml`.

Open `https://<CADDY_DOMAIN>`. Settings → HTTPS shows the state, the certificates with their expiry
dates and, in the local mode, the certificate for your devices.

**Turn it off** by removing `docker-compose.https.yml` from `COMPOSE_FILE`, then
`docker compose up -d --remove-orphans` (which stops Caddy). Port 8000 opens again.

**Upgrading from 0.2.0 or earlier:** the plain-HTTP port (`HTTP_PORT`, 80 by default) is gone;
remove it from `.env` and from any firewall rule. The certificate download moved to the HTTPS
address (below), and `docker compose up -d` adds the `caddy_control` volume that Settings → HTTPS
uses for the expiry dates, the renewal and the lifetime.

## Where the certificate comes from (`HTTPS_MODE`)

| Mode | Use it when | Needs | On devices |
|---|---|---|---|
| `local` (default) | The archive lives on your home network | Nothing | Install the server's certificate authority once per device |
| `letsencrypt-dns` | You own a domain and want a certificate every device trusts | A domain at a DNS provider with an API, and its API token | Nothing to install |
| `letsencrypt` | The server is reachable from the internet anyway | A public name and port 443 open to the internet | Nothing to install |

### `local`: the server's own certificate authority

Caddy creates a certificate authority ("Caddy Local Authority") in the `caddy_data` volume and
issues the server's certificate from it, for IP addresses and local names alike, without internet
access. The authority's root certificate is valid for ten years; the server certificates are
short-lived (12 hours by default, see below) and renewed automatically.

Devices trust the authority once. Until then the browser warns that the connection is not
private (you can still continue past the warning to download the certificate). Get the
certificate in any of these ways:

- **Settings → HTTPS → Download yadvault-ca.crt**, which also shows its SHA-256 fingerprint, its
  expiry date and the steps below for each kind of device.
- **`https://<server>/yadvault-ca.crt`** (with `:<HTTPS_PORT>` when it is not 443) from any device
  on the network, for one that cannot open the archive yet (a phone, for example): accept the
  browser's warning once to download it. Only the public certificate is served, never its key.
- **On the server:** `docker compose cp caddy:/data/caddy/pki/authorities/local/root.crt yadvault-ca.crt`

Check the fingerprint before you trust it: the device shows it in the certificate's details, and
`openssl x509 -in yadvault-ca.crt -noout -fingerprint -sha256` prints it. It must match the one in
Settings → HTTPS.

Install it:

- **Windows (Edge, Chrome):** open the file → Install Certificate → Current User (or Local
  Machine) → "Place all certificates in the following store" → Trusted Root Certification
  Authorities → Finish. Restart the browser.
- **macOS (Safari, Chrome):** open the file (Keychain Access adds it to the login keychain),
  double-click "Caddy Local Authority", Trust → "When using this certificate": Always Trust.
- **iPhone and iPad:** open `https://<server>/yadvault-ca.crt` in Safari, accept the warning once
  and allow the download. Settings → Profile Downloaded → Install. Then Settings → General →
  About → Certificate Trust Settings → turn on full trust for "Caddy Local Authority".
- **Android:** download the file, then Settings → Security and privacy → More security settings →
  Encryption and credentials → Install a certificate → CA certificate (names differ between
  makers; search Settings for "CA certificate"). Chrome trusts it at once; some apps ignore
  certificates added by the user.
- **Linux:** Debian and Ubuntu: `sudo cp yadvault-ca.crt /usr/local/share/ca-certificates/ && sudo update-ca-certificates`;
  Fedora: `sudo cp yadvault-ca.crt /etc/pki/ca-trust/source/anchors/ && sudo update-ca-trust`.
  Chrome on Linux keeps its own list: Settings → Privacy and security → Security → Manage
  certificates → Authorities → Import.
- **Firefox (every system)** keeps its own list: Settings → Privacy & Security → Certificates →
  View Certificates → Authorities → Import, and tick "Trust this CA to identify websites".

Several addresses: `CADDY_DOMAIN="archive.lan, 192.168.1.10"` serves both; then also set
`CADDY_DEFAULT_SNI=192.168.1.10`, the certificate a browser gets when it connects by IP address.

Keep the authority: it lives in the `caddy_data` volume. If that volume is deleted, Caddy creates
a new authority and every device has to install it again. To keep a copy:
`docker compose cp caddy:/data/caddy/pki ./caddy-pki` (it includes the private key: store it like
a backup).

#### Renewing the certificate authority

Settings → HTTPS → **Make a new authority** (admins) asks Caddy for a new certificate authority:
Caddy restarts for a few seconds with a new root certificate and new server certificates. Do this
when the authority nears its expiry date (the page shows it), or if its key may have been copied.
**Every device must then install the new yadvault-ca.crt**: the one they have stops working, and
browsers warn again until it is replaced. The page says so before you confirm.

#### How long each server certificate lasts

Caddy renews the server certificate on its own; each one lasts 12 hours by default. `CERT_LIFETIME`
in `.env` sets another default (`24h`, `168h`, `720h`, ...; up to a year), and Settings → HTTPS →
**Lifetime of each server certificate** changes it from the browser (admins); either way Caddy
restarts for a few seconds and issues new certificates. The authority's intermediate certificate
is kept at least four times as long as the server certificates, so a renewal never outlives its
issuer. Before you choose a long lifetime, read the warnings on the page: a copied private key
stays usable for the whole lifetime, and a change restarts Caddy. Twelve hours to a few days is
right for a home network. With a Let's Encrypt certificate the lifetime is Let's Encrypt's.

### `letsencrypt-dns`: a public certificate, server stays on the LAN

Let's Encrypt issues a certificate that every device already trusts. Caddy proves you own the
domain by creating a temporary DNS record through your DNS provider's API, so nothing has to be
reachable from the internet.

You need:

1. A domain at a DNS provider that has a [caddy-dns](https://github.com/caddy-dns) module taking a
   single API token, for example `cloudflare`, `duckdns`, `digitalocean` or `hetzner`.
2. An API token that may edit that domain's DNS records (Cloudflare: an API token with
   Zone → DNS → Edit for the zone; DuckDNS: your account token, with a name like
   `myarchive.duckdns.org`).
3. A DNS record that points the name at the server's LAN address, for example
   `archive.example.com A 192.168.1.10`, in public DNS or in your router's local DNS. Some routers
   drop public answers that point at private addresses ("DNS rebinding protection"): allow the
   name there, or add it to the router's local DNS.

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.https.yml:docker-compose.https-dns.yml
HTTPS_MODE=letsencrypt-dns
CADDY_DOMAIN=archive.example.com
DNS_PROVIDER=cloudflare
DNS_API_TOKEN=<token>
```

The first `docker compose up -d` builds Caddy with that provider's module (a few minutes; needs
internet access and about 1 GB of memory). Caddy then gets the certificate and renews it before
it expires. `DNS_RESOLVERS` (default `1.1.1.1 9.9.9.9`) are the public resolvers Caddy asks to
see the temporary record. Providers that need more than one value (Route 53, Porkbun, ...): edit
the `tls_letsencrypt-dns` snippet in `docker/caddy/Caddyfile` as the module's README describes.

### `letsencrypt`: a public certificate through the TLS-ALPN challenge

Let's Encrypt connects to the server from the internet on port 443 to check the name (the
TLS-ALPN challenge; there is no plain-HTTP port for the HTTP challenge), so `CADDY_DOMAIN` must be
a public name that points at your public address, with port 443 on the internet side forwarded to
this server's `HTTPS_PORT`. That also puts the sign-in page on the internet. For a private
archive, prefer `letsencrypt-dns`.

```bash
COMPOSE_FILE=docker-compose.yml:docker-compose.https.yml
HTTPS_MODE=letsencrypt
CADDY_DOMAIN=archive.example.com
```

## Behind a Cloudflare Tunnel or another proxy

A tunnel or reverse proxy of your own connects to Caddy over HTTPS: its origin is
`https://<server>:<HTTPS_PORT>`. With the local authority the proxy either trusts
`yadvault-ca.crt` (Cloudflare Tunnel: the public hostname's TLS settings, *Origin CA pool* and
*Origin server name* set to `CADDY_DOMAIN`) or skips verification of the origin (*No TLS Verify*;
the hop then stays encrypted but unverified). Add the public name to `CADDY_DOMAIN` so Caddy
answers for it, and keep the app's own port closed as it is with HTTPS on.

## What changes with HTTPS on

- Port 8000 is no longer published, and nothing listens for plain HTTP; `http://` addresses on
  the HTTPS port redirect to `https://`.
- Session cookies are marked Secure, and responses carry `Strict-Transport-Security`.
- The app trusts the client address Caddy forwards, so the login limits count each device. This
  is safe only because port 8000 is closed: never set `FORWARDED_ALLOW_IPS=*` while port 8000 is
  reachable.
- The MCP server is part of the app, at `https://<server>/mcp`, so its bearer tokens travel over
  HTTPS like everything else. With Let's Encrypt and the server reachable from the internet, it is
  reachable from there too, for whoever has a token with the `mcp` scope.
- Caddy runs through `docker/caddy/run.sh`, which also keeps the `caddy_control` volume: the
  certificates (never a key) for Settings → HTTPS to show, and the requests made there (a new
  authority, another lifetime), which it carries out by restarting Caddy.

## Troubleshooting

- **"Your connection is not private" (local mode):** the authority is not installed on that device
  yet, the browser keeps its own list (Firefox, Chrome on Linux), or a new authority was made in
  Settings → HTTPS and the device still has the old file.
- **The address works by name but not by IP address** (or the other way round): `CADDY_DOMAIN`
  must list every address you use, and `CADDY_DEFAULT_SNI` must be the IP address.
- **Caddy does not start:** `docker compose logs caddy`. Its port (`HTTPS_PORT`, default 443) must
  be free on the host; a wrong `HTTPS_MODE` shows as "File to import not found"; a lifetime that
  is not a duration is reported in Settings → HTTPS and replaced by 12 hours.
- **Settings → HTTPS shows no expiry dates, or cannot renew:** the stack runs an older
  `docker-compose.https.yml` without the `caddy_control` volume; take the file from this release
  and run `docker compose up -d`.
- **No certificate from Let's Encrypt:** `docker compose logs caddy | grep -i acme`. In the DNS
  mode check the token's permissions and that `DNS_PROVIDER` matches a caddy-dns module name; in
  the TLS-ALPN mode, that port 443 from the internet reaches `HTTPS_PORT`.
