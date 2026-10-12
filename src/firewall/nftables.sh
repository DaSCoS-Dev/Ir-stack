#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -euo pipefail
. /usr/local/lib/ir-stack/common.sh
ir_load_config
cmd="${1:-}"; arg="${2:-}"
LOCK_TABLE=ir_stack_lockdown
BAN_TABLE=ir_stack_ban

need(){ command -v nft >/dev/null 2>&1 || { echo 'nft non disponibile' >&2; exit 2; }; }
list_csv(){ local family="$1"; ir_normalize_sources "$TRUSTED_SOURCES" "$family" | paste -sd, -; }

lock_apply(){
    need
    nft list table inet "$LOCK_TABLE" >/dev/null 2>&1 && { echo 'lockdown nftables già attivo' >&2; return 1; }
    local v4 v6 tmp established_rule=''
    v4="$(list_csv 4)"; v6="$(list_csv 6)"; tmp="$(mktemp)"; trap 'rm -f "$tmp"' RETURN
    [[ "$LOCKDOWN_KEEP_ESTABLISHED" == yes ]] && established_rule='ct state established,related accept'
    cat >"$tmp" <<EOF2
 table inet $LOCK_TABLE {
   set trusted_v4 { type ipv4_addr; flags interval; auto-merge; elements = { $v4 } }
   set trusted_v6 { type ipv6_addr; flags interval; auto-merge; elements = { $v6 } }
   chain input {
     type filter hook input priority -300; policy drop;
     iifname "lo" accept
     $established_rule
     ip saddr @trusted_v4 tcp dport $SSH_PORT accept
     ip protocol icmp ip saddr @trusted_v4 accept
     ip6 saddr @trusted_v6 tcp dport $SSH_PORT accept
     icmpv6 type { destination-unreachable, packet-too-big, time-exceeded, parameter-problem, nd-router-solicit, nd-router-advert, nd-neighbor-solicit, nd-neighbor-advert } accept
   }
 }
EOF2
    nft -f "$tmp"
}
lock_rollback(){ need; nft delete table inet "$LOCK_TABLE" 2>/dev/null || true; }
lock_status(){ need; nft list table inet "$LOCK_TABLE"; }

ban_ensure(){
    need
    nft list table inet "$BAN_TABLE" >/dev/null 2>&1 && return 0
    nft -f - <<EOF2
 table inet $BAN_TABLE {
   set banned_v4 { type ipv4_addr; }
   set banned_v6 { type ipv6_addr; }
   chain input {
     type filter hook input priority -250; policy accept;
     ip saddr @banned_v4 drop
     ip6 saddr @banned_v6 drop
   }
 }
EOF2
}
ban_add(){ local ip; ip="$(ir_validate_ip "$1")"; ban_ensure; if [[ "$ip" == *:* ]]; then nft -exist add element inet "$BAN_TABLE" banned_v6 "{ $ip }"; else nft -exist add element inet "$BAN_TABLE" banned_v4 "{ $ip }"; fi; }
ban_del(){ local ip; ip="$(ir_validate_ip "$1")"; need; if [[ "$ip" == *:* ]]; then nft delete element inet "$BAN_TABLE" banned_v6 "{ $ip }" 2>/dev/null || true; else nft delete element inet "$BAN_TABLE" banned_v4 "{ $ip }" 2>/dev/null || true; fi; }
ban_status(){ need; nft list table inet "$BAN_TABLE" 2>/dev/null || echo 'nessuna tabella ban IR Stack'; }
ban_flush(){ need; nft delete table inet "$BAN_TABLE" 2>/dev/null || true; }

case "$cmd" in
 lockdown-apply) lock_apply;; lockdown-rollback) lock_rollback;; lockdown-status) lock_status;;
 ban-add) ban_add "$arg";; ban-del) ban_del "$arg";; ban-status) ban_status;; ban-flush) ban_flush;; check) need;;
 *) echo "Uso: $0 lockdown-apply|lockdown-rollback|lockdown-status|ban-add IP|ban-del IP|ban-status|ban-flush|check" >&2; exit 2;;
esac
