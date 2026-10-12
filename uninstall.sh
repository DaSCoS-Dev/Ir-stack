#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -Eeuo pipefail
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "Eseguire come root" >&2; exit 1; }
PURGE_CONFIG=no; PURGE_STATE=no
while (($#)); do case "$1" in --purge-config) PURGE_CONFIG=yes;; --purge-state) PURGE_STATE=yes;; *) echo "Uso: $0 [--purge-config] [--purge-state]"; exit 2;; esac; shift; done

# IMPORTANT: remove firewall objects before deleting rollback/drivers/config.
if [[ -x /usr/local/sbin/emergency-lockdown-rollback.sh ]]; then
    /usr/local/sbin/emergency-lockdown-rollback.sh 2>/dev/null || true
fi
# Best-effort cleanup also covers orphaned firewall objects for which state was lost.
for backend in nftables iptables firewalld; do
    driver="/usr/local/lib/ir-stack/firewall/$backend.sh"
    [[ -x "$driver" ]] || continue
    "$driver" lockdown-rollback 2>/dev/null || true
    "$driver" ban-flush 2>/dev/null || true
done

units=(ir-stack-identity.path ir-stack-identity.timer ir-stack-ssh-login.timer ir-stack-self-watch.path ir-stack-guardians.timer)
systemctl disable --now "${units[@]}" 2>/dev/null || true
rm -f /etc/systemd/system/ir-stack-*.service /etc/systemd/system/ir-stack-*.timer /etc/systemd/system/ir-stack-*.path
rm -f /etc/audit/rules.d/40-ir-stack-identity.rules /etc/audit/rules.d/41-ir-stack-self.rules /etc/audit/rules.d/42-ir-stack-sshkeys.rules
rm -f /usr/local/sbin/check-identity-anomalies.sh /usr/local/sbin/identity-incident-handler.sh /usr/local/sbin/ssh-login-alert.sh /usr/local/sbin/ir-stack-watch.sh /usr/local/sbin/ir-guardians-watchdog.sh /usr/local/sbin/emergency-lockdown.sh /usr/local/sbin/emergency-lockdown-rollback.sh /usr/local/sbin/refresh-audit-rules.sh /usr/local/sbin/refresh-ssh-key-audit.sh /usr/local/sbin/ir-ban /usr/local/sbin/ir-openwrt-ban /usr/local/sbin/irctl
rm -rf /usr/local/lib/ir-stack /usr/local/share/ir-stack
rm -f /etc/fail2ban/action.d/ir-stack.conf
rm -f /etc/profile.d/irctl.sh
[[ "$PURGE_CONFIG" == yes ]] && rm -rf /etc/ir-stack
[[ "$PURGE_STATE" == yes ]] && rm -rf /var/lib/ir-stack /run/ir-stack
systemctl daemon-reload
if command -v augenrules >/dev/null 2>&1; then augenrules --load || echo 'ATTENZIONE: impossibile ricaricare audit rules dopo uninstall' >&2; fi
echo "IR Stack rimosso. I pacchetti dipendenza, Postfix e l'helper OpenWrt remoto non vengono disinstallati automaticamente."
