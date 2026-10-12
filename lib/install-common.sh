#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -euo pipefail

say() { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die() { printf '[ERRORE] %s\n' "$*" >&2; exit 1; }

require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Eseguire come root."; }
require_systemd() { command -v systemctl >/dev/null 2>&1 || die "systemd non disponibile."; }
require_apt() { command -v apt-get >/dev/null 2>&1 || die "Questa release supporta sistemi apt-based."; }

yesno() {
    local prompt="$1" default="${2:-no}" answer
    if [[ "$NON_INTERACTIVE" == yes ]]; then [[ "$default" == yes ]]; return; fi
    local hint='[y/N]'; [[ "$default" == yes ]] && hint='[Y/n]'
    read -r -p "$prompt $hint " answer || true
    answer="${answer:-$default}"
    [[ "$answer" =~ ^([yY]|[yY][eE][sS]|[sS]|[sS][iI])$ ]]
}

ask() {
    local var="$1" prompt="$2" default="${3:-}" secret="${4:-no}" value
    [[ "$NON_INTERACTIVE" == yes ]] && return 0
    if [[ "$secret" == yes ]]; then
        read -r -s -p "$prompt${default:+ [$default]}: " value || true; echo
    else
        read -r -p "$prompt${default:+ [$default]}: " value || true
    fi
    printf -v "$var" '%s' "${value:-$default}"
}

# Config files are data, never shell programs. Only these keys are accepted.
ir_config_key_allowed() {
    case "$1" in
        ALERT_EMAIL|MAIL_MODE|RELAY_HOST|RELAY_PORT|RELAY_TLS|RELAY_TLS_MODE|RELAY_AUTH|RELAY_USER|\
        TRUSTED_SOURCES|TRUSTED_IPV4|TRUSTED_IPV6|FIREWALL_BACKEND|LOCKDOWN_KEEP_ESTABLISHED|\
        BAN_BACKENDS|FAIL2BAN_INTEGRATION|OPENWRT_REMOTE_ENABLE|OPENWRT_HOST|OPENWRT_PORT|OPENWRT_USER|\
        OPENWRT_IDENTITY_FILE|OPENWRT_KNOWN_HOSTS|SSH_PORT|ENABLE_LOCKDOWN|HARDEN_SSH_LOGGING|\
        IDENTITY_SHELL_WHITELIST) return 0 ;;
        *) return 1 ;;
    esac
}

ir_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

ir_config_decode_value() {
    local v; v="$(ir_trim "$1")"
    if [[ ${#v} -ge 2 && ${v:0:1} == '"' && ${v: -1} == '"' ]]; then
        v="${v:1:${#v}-2}"
        v="${v//\\\"/\"}"
        v="${v//\\\\/\\}"
    elif [[ ${#v} -ge 2 && ${v:0:1} == "'" && ${v: -1} == "'" ]]; then
        v="${v:1:${#v}-2}"
    fi
    [[ "$v" != *$'\n'* && "$v" != *$'\r'* ]] || return 2
    printf '%s' "$v"
}

ir_load_config_file() {
    local file="$1" line key rhs value lineno=0
    [[ -r "$file" ]] || die "Config non leggibile: $file"
    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno+1)); line="${line%$'\r'}"
        [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue
        if [[ "$line" =~ ^[[:space:]]*([A-Z][A-Z0-9_]*)[[:space:]]*=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"; rhs="${BASH_REMATCH[2]}"
        else
            die "Config $file:$lineno non valida: atteso KEY=VALUE"
        fi
        ir_config_key_allowed "$key" || die "Config $file:$lineno: chiave non ammessa: $key"
        value="$(ir_config_decode_value "$rhs")" || die "Config $file:$lineno: valore non valido per $key"
        printf -v "$key" '%s' "$value"
    done < "$file"
}

ir_config_quote() {
    local s="$1"
    [[ "$s" != *$'\n'* && "$s" != *$'\r'* ]] || die "Valore config contiene newline"
    s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
    printf '"%s"' "$s"
}

ir_config_line() { printf '%s=%s\n' "$1" "$(ir_config_quote "$2")"; }
