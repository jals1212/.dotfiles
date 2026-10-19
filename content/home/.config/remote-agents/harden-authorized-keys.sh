#!/bin/bash
#
# Re-apply SSH key hardening after a Moshi Easy Pair re-pairing.
#
# Easy Pair appends a fresh key to ~/.ssh/authorized_keys with NO restrictions,
# so every re-pairing silently reopens the "any tailnet node can log in" hole.
# This script re-applies the restriction to any unrestricted key.
#
# The iPhone's tailnet IP is discovered from Tailscale rather than hardcoded:
# it is stable per node, but a node re-registration can change it, and a stale
# hardcoded value would lock you out.
#

set -euo pipefail

AK="${HOME}/.ssh/authorized_keys"
PEER_OS="iOS"

[ -f "$AK" ] || { echo "FATAL: $AK not found"; exit 1; }

# Discover the tailnet IPv4 of the iOS peer.
PEER_IP=$(tailscale status --json 2>/dev/null | python3 -c "
import json,sys
d=json.load(sys.stdin)
for p in (d.get('Peer') or {}).values():
    if p.get('OS')=='$PEER_OS':
        for ip in p.get('TailscaleIPs') or []:
            if ':' not in ip:
                print(ip); raise SystemExit
" || true)

if [ -z "${PEER_IP:-}" ]; then
	echo "FATAL: could not discover the $PEER_OS peer tailnet IP. Is Tailscale up?"
	echo "Run 'tailscale status' and apply the prefix manually."
	exit 1
fi

echo "Discovered $PEER_OS peer at $PEER_IP"

BACKUP="${AK}.bak-$(date +%Y%m%d-%H%M%S)"
cp -p "$AK" "$BACKUP"
echo "Backup: $BACKUP"

OPTS="from=\"${PEER_IP}\",restrict,pty"

# Prefix only key lines that carry no options yet. A key line starts directly
# with the key type; an already-restricted line starts with the options field.
awk -v opts="$OPTS" '
	/^[[:space:]]*($|#)/ { print; next }
	$1 ~ /^(ssh-|ecdsa-|sk-)/ { print opts " " $0; next }
	{ print }
' "$AK" >"${AK}.new"

chmod 600 "${AK}.new"
mv "${AK}.new" "$AK"

echo
echo "=== Result ==="
awk '{print NR": "substr($0,1,60)"..."}' "$AK"

echo
echo "=== Key material check ==="
# Compare the set of public key blobs before and after; they must be identical.
if diff <(grep -oE '[A-Za-z0-9+/]{40,}={0,2}' "$BACKUP" | sort) \
        <(grep -oE '[A-Za-z0-9+/]{40,}={0,2}' "$AK" | sort) >/dev/null; then
	echo "OK: key material unchanged"
else
	echo "ALERT: key material differs from backup - inspect before trusting"
	exit 1
fi

echo
echo "Keys present: $(grep -c '^[^#]' "$AK" 2>/dev/null || echo 0)"
echo "If an old/unused key is listed above, remove that line manually."
