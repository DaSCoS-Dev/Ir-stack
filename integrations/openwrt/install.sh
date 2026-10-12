#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -eu
ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
PUBKEY_FILE=''
while [ "$#" -gt 0 ]; do case "$1" in --public-key-file) PUBKEY_FILE="$2"; shift 2;; -h|--help) echo "Uso: $0 [--public-key-file FILE]"; exit 0;; *) echo "Opzione sconosciuta: $1" >&2; exit 2;; esac; done
[ "$(id -u)" -eq 0 ] || { echo 'Eseguire come root' >&2; exit 1; }
command -v nft >/dev/null 2>&1 || { echo 'nft non disponibile: OpenWrt fw4/nftables richiesto' >&2; exit 2; }
install -d -m 755 /usr/libexec
install -m 700 "$ROOT/usr/libexec/ir-stack-firewall" /usr/libexec/ir-stack-firewall
install -m 700 "$ROOT/usr/libexec/ir-stack-firewall-ssh-wrapper" /usr/libexec/ir-stack-firewall-ssh-wrapper
if [ ! -x /usr/bin/f2b-banip ]; then
  install -d -m 755 /usr/share/nftables.d/ruleset-post
  install -m 644 "$ROOT/usr/share/nftables.d/ruleset-post/95-ir-stack.nft" /usr/share/nftables.d/ruleset-post/95-ir-stack.nft
  /etc/init.d/firewall reload
fi
if [ -n "$PUBKEY_FILE" ]; then
  [ -s "$PUBKEY_FILE" ] || { echo "Public key non leggibile: $PUBKEY_FILE" >&2; exit 2; }
  auth=/etc/dropbear/authorized_keys
  mkdir -p /etc/dropbear; touch "$auth"; chmod 700 /etc/dropbear; chmod 600 "$auth"
  lines="$(wc -l < "$PUBKEY_FILE" | tr -d ' ')"
  [ "$lines" -eq 1 ] || { echo 'La public key deve essere una singola riga' >&2; exit 2; }
  key="$(cat "$PUBKEY_FILE")"
  case "$key" in ssh-ed25519\ *) ;; *) echo 'È accettata soltanto una chiave pubblica ssh-ed25519 senza opzioni' >&2; exit 2;; esac
  line="restrict,command=\"/usr/libexec/ir-stack-firewall-ssh-wrapper\" $key"
  grep -Fqx "$line" "$auth" 2>/dev/null || printf '%s\n' "$line" >> "$auth"
fi
/usr/libexec/ir-stack-firewall check
echo 'OpenWrt IR Stack helper installato.'
