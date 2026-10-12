#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HOST=''; PORT=22; USER=root; IDENTITY="${HOME}/.config/ir-stack/openwrt_ed25519"; KNOWN_HOSTS="${HOME}/.config/ir-stack/openwrt_known_hosts"; EXPECTED_FP=''; NON_INTERACTIVE=no
usage(){ echo "Uso: $0 --host HOST [--port 22] [--user root] [--identity FILE] [--known-hosts FILE] [--host-key SHA256:...] [--non-interactive]"; }
while (($#)); do case "$1" in --host) HOST="${2:?}"; shift 2;; --port) PORT="${2:?}"; shift 2;; --user) USER="${2:?}"; shift 2;; --identity) IDENTITY="${2:?}"; shift 2;; --known-hosts) KNOWN_HOSTS="${2:?}"; shift 2;; --host-key) EXPECTED_FP="${2:?}"; shift 2;; --non-interactive) NON_INTERACTIVE=yes; shift;; -h|--help) usage; exit 0;; *) echo "Opzione sconosciuta $1" >&2; exit 2;; esac; done
[[ -n "$HOST" ]] || { usage; exit 2; }
if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT <= 0 || PORT >= 65536 )); then echo 'Porta non valida' >&2; exit 2; fi
[[ "$USER" =~ ^[A-Za-z0-9._-]+$ ]] || { echo 'Utente SSH non valido' >&2; exit 2; }
[[ "$HOST" != *$'\n'* && "$HOST" != *$'\r'* ]] || { echo 'Host non valido' >&2; exit 2; }
for c in ssh ssh-keygen ssh-keyscan tar; do command -v "$c" >/dev/null || { echo "$c assente" >&2; exit 2; }; done
mkdir -p "$(dirname "$IDENTITY")" "$(dirname "$KNOWN_HOSTS")"; chmod 700 "$(dirname "$IDENTITY")" "$(dirname "$KNOWN_HOSTS")" 2>/dev/null || true
if [[ ! -s "$IDENTITY" ]]; then ssh-keygen -q -t ed25519 -N '' -C "ir-stack@$HOST" -f "$IDENTITY"; fi
chmod 600 "$IDENTITY"; chmod 644 "$IDENTITY.pub"
tmp_all="$(mktemp)"; tmp_one="$(mktemp)"; trap 'rm -f "$tmp_all" "$tmp_one"' EXIT
ssh-keyscan -t ed25519 -p "$PORT" -T 8 "$HOST" > "$tmp_all" 2>/dev/null || true
if [[ ! -s "$tmp_all" ]]; then ssh-keyscan -t ecdsa,rsa -p "$PORT" -T 8 "$HOST" > "$tmp_all" 2>/dev/null || true; fi
[[ -s "$tmp_all" ]] || { echo 'Impossibile ottenere host key' >&2; exit 2; }
head -n 1 "$tmp_all" > "$tmp_one"
fp="$(ssh-keygen -lf "$tmp_one" -E sha256 | awk 'NR==1{print $2}')"
keytype="$(awk 'NR==1{print $2}' "$tmp_one")"
echo "OpenWrt host key: type=$keytype fingerprint=$fp"
if [[ -n "$EXPECTED_FP" ]]; then
    [[ "$fp" == "$EXPECTED_FP" ]] || { echo 'Fingerprint non corrisponde' >&2; exit 3; }
elif [[ "$NON_INTERACTIVE" == yes ]]; then
    echo '--non-interactive richiede --host-key' >&2; exit 3
else
    echo 'ATTENZIONE: senza confronto out-of-band questa conferma è TOFU, non host-key pinning forte.' >&2
    read -r -p 'Hai verificato questo fingerprint da una fonte fidata/console del router? [y/N] ' a
    [[ "$a" =~ ^[yY] ]] || exit 3
fi
install -m 600 "$tmp_one" "$KNOWN_HOSTS"
sshopts=(-F /dev/null -p "$PORT" -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN_HOSTS")
tar -C "$ROOT/integrations/openwrt" -czf - . | ssh "${sshopts[@]}" "$USER@$HOST" 'rm -rf /tmp/ir-stack-openwrt && mkdir -p /tmp/ir-stack-openwrt && tar -xzf - -C /tmp/ir-stack-openwrt'
ssh "${sshopts[@]}" "$USER@$HOST" 'cat > /tmp/ir-stack-openwrt/ir-stack.pub && chmod 600 /tmp/ir-stack-openwrt/ir-stack.pub && /tmp/ir-stack-openwrt/install.sh --public-key-file /tmp/ir-stack-openwrt/ir-stack.pub' < "$IDENTITY.pub"
ssh -F /dev/null -i "$IDENTITY" -p "$PORT" -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$KNOWN_HOSTS" "$USER@$HOST" check
echo
echo 'Bootstrap completato. Inserisci nella config IR Stack:'
printf 'OPENWRT_REMOTE_ENABLE="yes"\nOPENWRT_HOST="%s"\nOPENWRT_PORT="%s"\nOPENWRT_USER="%s"\nOPENWRT_IDENTITY_FILE="%s"\nOPENWRT_KNOWN_HOSTS="%s"\n' "$HOST" "$PORT" "$USER" "$IDENTITY" "$KNOWN_HOSTS"
