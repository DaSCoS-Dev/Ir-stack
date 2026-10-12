#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -euo pipefail
. /usr/local/lib/ir-stack/common.sh
ir_load_config
cmd="${1:-}"; arg="${2:-}"
LCHAIN=IR_STACK_LOCKDOWN
BCHAIN=IR_STACK_BAN
need() {
    if ! command -v iptables >/dev/null 2>&1 || ! command -v ip6tables >/dev/null 2>&1; then
        echo 'iptables/ip6tables non disponibili' >&2
        exit 2
    fi
}
ensure_chain(){ local bin="$1" chain="$2"; "$bin" -N "$chain" 2>/dev/null || true; "$bin" -C INPUT -j "$chain" 2>/dev/null || "$bin" -I INPUT 1 -j "$chain"; }
remove_chain(){ local bin="$1" chain="$2"; while "$bin" -C INPUT -j "$chain" 2>/dev/null; do "$bin" -D INPUT -j "$chain"; done; "$bin" -F "$chain" 2>/dev/null || true; "$bin" -X "$chain" 2>/dev/null || true; }
lock_apply(){
    need; remove_chain iptables "$LCHAIN"; remove_chain ip6tables "$LCHAIN"
    if ! {
        ensure_chain iptables "$LCHAIN"; ensure_chain ip6tables "$LCHAIN"
        iptables -A "$LCHAIN" -i lo -j RETURN
        ip6tables -A "$LCHAIN" -i lo -j RETURN
        if [[ "$LOCKDOWN_KEEP_ESTABLISHED" == yes ]]; then
            iptables -A "$LCHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
            ip6tables -A "$LCHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
        fi
        while read -r src; do [[ -n "$src" ]] || continue; iptables -A "$LCHAIN" -s "$src" -p tcp --dport "$SSH_PORT" -j RETURN; iptables -A "$LCHAIN" -s "$src" -p icmp -j RETURN; done < <(ir_normalize_sources "$TRUSTED_SOURCES" 4)
        while read -r src; do [[ -n "$src" ]] || continue; ip6tables -A "$LCHAIN" -s "$src" -p tcp --dport "$SSH_PORT" -j RETURN; ip6tables -A "$LCHAIN" -s "$src" -p ipv6-icmp -j RETURN; done < <(ir_normalize_sources "$TRUSTED_SOURCES" 6)
        iptables -A "$LCHAIN" -j DROP; ip6tables -A "$LCHAIN" -j DROP
    }; then
        remove_chain iptables "$LCHAIN"; remove_chain ip6tables "$LCHAIN"; return 1
    fi
}
lock_rollback(){ need; remove_chain iptables "$LCHAIN"; remove_chain ip6tables "$LCHAIN"; }
lock_status(){ need; iptables -S "$LCHAIN" 2>/dev/null || true; ip6tables -S "$LCHAIN" 2>/dev/null || true; }
ban_add(){ local ip bin; ip="$(ir_validate_ip "$1")"; need; if [[ "$ip" == *:* ]]; then bin=ip6tables; else bin=iptables; fi; ensure_chain "$bin" "$BCHAIN"; "$bin" -C "$BCHAIN" -s "$ip" -j DROP 2>/dev/null || "$bin" -A "$BCHAIN" -s "$ip" -j DROP; }
ban_del(){ local ip bin; ip="$(ir_validate_ip "$1")"; need; if [[ "$ip" == *:* ]]; then bin=ip6tables; else bin=iptables; fi; while "$bin" -C "$BCHAIN" -s "$ip" -j DROP 2>/dev/null; do "$bin" -D "$BCHAIN" -s "$ip" -j DROP; done; }
ban_status(){ need; iptables -S "$BCHAIN" 2>/dev/null || true; ip6tables -S "$BCHAIN" 2>/dev/null || true; }
ban_flush(){ need; remove_chain iptables "$BCHAIN"; remove_chain ip6tables "$BCHAIN"; }
case "$cmd" in
 lockdown-apply) lock_apply;; lockdown-rollback) lock_rollback;; lockdown-status) lock_status;; ban-add) ban_add "$arg";; ban-del) ban_del "$arg";; ban-status) ban_status;; ban-flush) ban_flush;; check) need;; *) echo "Uso: $0 ..." >&2; exit 2;;
esac
