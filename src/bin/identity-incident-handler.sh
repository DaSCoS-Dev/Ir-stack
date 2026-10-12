#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -euo pipefail
. /usr/local/lib/ir-stack/common.sh
ir_load_config
LOGFILE="/var/log/ir-stack-identity.log"
SOURCE="${1:-unknown}"
HOST="$(ir_host)"
{
    echo "============================================================"
    echo "[$(date --iso-8601=seconds)] source=$SOURCE identity check"
} >> "$LOGFILE"
if /usr/local/sbin/check-identity-anomalies.sh >> "$LOGFILE" 2>&1; then
    ir_log ir-stack-identity "SOURCE=$SOURCE nessuna anomalia critica"
    exit 0
fi
ir_log ir-stack-identity "SOURCE=$SOURCE ANOMALIA CRITICA rilevata"
BODY="$(tail -n 160 "$LOGFILE")"
if ir_maintenance_active; then
    ir_log ir-stack-identity "maintenance attiva: escalation e lockdown soppressi"
    exit 0
fi
ir_send_mail "[IR ALERT] Identity anomaly su $HOST" "$BODY" || true
if [[ "$ENABLE_LOCKDOWN" == yes ]]; then
    if [[ -z "$(ir_normalize_sources "$TRUSTED_SOURCES" any)" ]]; then
        ir_log ir-stack-identity "lockdown richiesto ma TRUSTED_SOURCES vuoto: NON applicato"
        printf -v ERR_BODY 'TRUSTED_SOURCES non configurata.\n\n%s' "$BODY"
        ir_send_mail "[IR ERROR] Lockdown non applicato su $HOST" "$ERR_BODY" || true
        exit 1
    fi
    /usr/local/sbin/emergency-lockdown.sh >> "$LOGFILE" 2>&1
    ir_log ir-stack-identity "lockdown applicato"
    ir_send_mail "[IR LOCKDOWN] Server isolato $HOST" "$(tail -n 160 "$LOGFILE")" || true
fi
