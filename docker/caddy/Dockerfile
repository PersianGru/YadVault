# Caddy for docker-compose.https.yml. The build target is HTTPS_MODE: `local` and `letsencrypt`
# are the official image as it is; `letsencrypt-dns` adds the DNS provider module named by
# DNS_PROVIDER (github.com/caddy-dns/<name>, for example cloudflare, duckdns, digitalocean,
# hetzner), built once with xcaddy. Only the stage of the chosen target is built.
ARG CADDY_VERSION=2

FROM caddy:${CADDY_VERSION}-alpine AS local

FROM local AS letsencrypt

FROM caddy:${CADDY_VERSION}-builder-alpine AS dns-build
ARG DNS_PROVIDER=""
RUN if [ -z "$DNS_PROVIDER" ]; then echo "HTTPS_MODE=letsencrypt-dns needs DNS_PROVIDER in .env (for example cloudflare)" >&2; exit 1; fi \
    && xcaddy build --with "github.com/caddy-dns/${DNS_PROVIDER}"

FROM local AS letsencrypt-dns
COPY --from=dns-build /usr/bin/caddy /usr/bin/caddy
