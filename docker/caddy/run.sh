#!/bin/sh
# Runs Caddy in its container and carries out what Settings → HTTPS asks, through the control
# volume shared with the app (/control): the app reads the certificates there (never a key) and
# their state, and leaves requests as files. Used with the official Caddy image by
# docker-compose.https.yml, and by any other stack that runs Caddy the same way.
#
#   /control/ca.crt            the local certificate authority's certificate (the file devices install)
#   /control/certs/<name>.crt  the server certificates Caddy serves right now
#   /control/status            key=value lines: the lifetimes in use, when Caddy started, restarts
#   /control/cert-lifetime     a request: the server certificate's lifetime, e.g. 12h or 720h
#                              (CERT_LIFETIME in .env is the default; empty or missing = that)
#   /control/reload            a request: restart Caddy, so a new lifetime takes effect
#   /control/renew-ca          a request: make a new certificate authority (every device must then
#                              install the new ca.crt), then restart Caddy
#
# Caddy's own files under /data/caddy stay as they are: the local authority's key never leaves it.
set -u

CONTROL="${CONTROL_DIR:-/control}"
DATA="${CADDY_DATA:-/data/caddy}"
CONFIG="${CADDY_CONFIG:-/etc/caddy/Caddyfile}"
POLL="${CONTROL_POLL_SECONDS:-5}"
MAX_HOURS=8760  # a year: longer than that would exceed what the authority's own certificates allow

mkdir -p "$CONTROL/certs"
chmod 1777 "$CONTROL" 2>/dev/null || true   # the app (another user) leaves its requests here
chmod 755 "$CONTROL/certs" 2>/dev/null || true

pid=""
started=""
restarts=0
last_renew=""
last_reload=""
last_error=""
LIFETIME="12h"
INTERMEDIATE="168h"

log() {
	echo "run.sh: $*" >&2
}

hours_of() {  # "12h" -> 12, "7d" -> 168; fails when it is not a duration
	case "$1" in
		"" | *[!0-9hd]* | *[hd]?*) return 1 ;;
	esac
	n="${1%?}"
	[ -n "$n" ] || return 1
	case "$1" in
		*d) echo $((n * 24)) ;;
		*h) echo "$n" ;;
		*) return 1 ;;
	esac
}

read_lifetime() {
	want="${CERT_LIFETIME:-12h}"
	if [ -f "$CONTROL/cert-lifetime" ]; then
		asked=$(tr -d ' \r\n' < "$CONTROL/cert-lifetime")
		[ -n "$asked" ] && want="$asked"
	fi
	hours=$(hours_of "$want") || hours=""
	if [ -z "$hours" ] || [ "$hours" -lt 1 ] || [ "$hours" -gt "$MAX_HOURS" ]; then
		last_error="cert-lifetime '$want' is not a duration from 1h to ${MAX_HOURS}h; using 12h"
		log "$last_error"
		hours=12
	fi
	LIFETIME="${hours}h"
	# the intermediate certificate must outlive the server certificates it signs
	inter=$((hours * 4))
	[ "$inter" -lt 168 ] && inter=168
	INTERMEDIATE="${inter}h"
	export CERT_LIFETIME="$LIFETIME" CA_INTERMEDIATE_LIFETIME="$INTERMEDIATE"
}

copy_if_newer() {  # $1 source, $2 copy
	if [ ! -f "$2" ] || [ "$1" -nt "$2" ]; then
		cp "$1" "$2.tmp" && chmod 644 "$2.tmp" && mv "$2.tmp" "$2"
	fi
}

publish() {  # the certificates (never a key) and the state, for the app to read
	root="$DATA/pki/authorities/local/root.crt"
	if [ -f "$root" ]; then
		copy_if_newer "$root" "$CONTROL/ca.crt"
	else
		rm -f "$CONTROL/ca.crt"
	fi
	for crt in "$DATA"/certificates/*/*/*.crt; do
		[ -f "$crt" ] || continue
		copy_if_newer "$crt" "$CONTROL/certs/$(basename "$crt")"
	done
	for copy in "$CONTROL"/certs/*.crt; do
		[ -f "$copy" ] || continue
		found=""
		for crt in "$DATA"/certificates/*/*/"$(basename "$copy")"; do
			[ -f "$crt" ] && found=1
		done
		[ -n "$found" ] || rm -f "$copy"
	done
	{
		echo "lifetime=$LIFETIME"
		echo "intermediate_lifetime=$INTERMEDIATE"
		echo "started=$started"
		echo "restarts=$restarts"
		echo "last_renew=$last_renew"
		echo "last_reload=$last_reload"
		echo "last_error=$last_error"
		echo "updated=$(date +%s)"
	} > "$CONTROL/status.tmp" && chmod 644 "$CONTROL/status.tmp" && mv "$CONTROL/status.tmp" "$CONTROL/status"
}

start_caddy() {
	read_lifetime
	caddy run --config "$CONFIG" --adapter caddyfile &
	pid=$!
	started=$(date +%s)
	log "caddy started (pid $pid), server certificates valid $LIFETIME, intermediate $INTERMEDIATE"
}

stop_caddy() {
	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
		kill -TERM "$pid" 2>/dev/null
		wait "$pid" 2>/dev/null
	fi
	pid=""
}

finish() {
	stop_caddy
	exit 0
}
trap finish TERM INT

start_caddy
while :; do
	if ! kill -0 "$pid" 2>/dev/null; then
		wait "$pid"
		code=$?
		log "caddy exited with status $code"
		exit "$code"
	fi
	if [ -f "$CONTROL/renew-ca" ]; then
		rm -f "$CONTROL/renew-ca"
		log "making a new certificate authority, as asked in Settings: every device installs the new ca.crt"
		stop_caddy
		rm -rf "$DATA/pki/authorities/local" "$DATA/certificates/local"
		rm -f "$CONTROL/ca.crt" "$CONTROL"/certs/*.crt
		restarts=$((restarts + 1))
		last_renew=$(date +%s)
		last_error=""
		start_caddy
	elif [ -f "$CONTROL/reload" ]; then
		rm -f "$CONTROL/reload"
		log "restarting caddy for the new certificate lifetime"
		stop_caddy
		rm -rf "$DATA/certificates/local"  # the local authority issues new server certificates with the new lifetime
		restarts=$((restarts + 1))
		last_reload=$(date +%s)
		last_error=""
		start_caddy
	fi
	publish
	sleep "$POLL" &
	wait $!
done
