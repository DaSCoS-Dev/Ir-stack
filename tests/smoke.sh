#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0
while IFS= read -r -d '' f; do
    if ! bash -n "$f"; then echo "bash -n FAIL: $f" >&2; failed=1; fi
done < <(find "$ROOT" -type f \( -name '*.sh' -o -name irctl -o -name ir-ban -o -name ir-openwrt-ban \) -print0)
for f in "$ROOT"/integrations/openwrt/install.sh "$ROOT"/integrations/openwrt/usr/libexec/ir-stack-firewall "$ROOT"/integrations/openwrt/usr/libexec/ir-stack-firewall-ssh-wrapper; do
    sh -n "$f" || { echo "sh -n FAIL: $f" >&2; failed=1; }
done
for required in src/bin/check-identity-anomalies.sh src/bin/identity-incident-handler.sh src/bin/ssh-login-alert.sh src/bin/ssh-key-inventory.sh src/bin/accept-ssh-key-baseline.sh src/bin/refresh-audit-rules.sh src/bin/irctl src/bin/ir-ban src/bin/ir-openwrt-ban src/lib/common.sh src/firewall/nftables.sh src/firewall/iptables.sh src/firewall/firewalld.sh integrations/fail2ban/action.d/ir-stack.conf integrations/openwrt/install.sh; do
    [[ -f "$ROOT/$required" ]] || { echo "MISSING: $required" >&2; failed=1; }
done

rm -f /tmp/ir-stack-config-rce-test
cfg="$(mktemp)"; trap 'rm -f "$cfg"' EXIT
cat > "$cfg" <<'CFG'
ALERT_EMAIL="$(touch /tmp/ir-stack-config-rce-test)"
CFG
(
    source "$ROOT/lib/install-common.sh"
    ALERT_EMAIL=''
    ir_load_config_file "$cfg"
    [[ "$ALERT_EMAIL" == '$(touch /tmp/ir-stack-config-rce-test)' ]]
) || failed=1
[[ ! -e /tmp/ir-stack-config-rce-test ]] || { echo 'CONFIG RCE REGRESSION' >&2; failed=1; }
rm -f /tmp/ir-stack-config-rce-test

exit "$failed"
