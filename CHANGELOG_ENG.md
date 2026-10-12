# Changelog

[Italiano](CHANGELOG.md) | **English**

## 0.2.0-rc1

Complete security/code review of `0.2.0-dev` and pre-publication remediation.

### Security

- configuration files are no longer executed with `source`: allowlisted `KEY=VALUE` parser;
- uninstall performs firewall rollback/cleanup before removing recovery tools;
- OpenWrt host-key pinning is limited to the single key that was actually verified;
- audit rules are generated dynamically for existing objects; `augenrules` errors are no longer hidden;
- explicit handling of audit immutable/reboot-required state;
- `LOCKDOWN_KEEP_ESTABLISHED=no` is now the default containment behavior;
- SSH journald cursor is updated atomically, with explicit recovery from an invalid cursor;
- `authorized_keys` baseline with manual acceptance;
- authenticated SMTP requires TLS `verify` or `encrypt`;
- SMTP passwords can be supplied through a file to avoid exposure in shell history/process listings;
- semantic IP validation in the OpenWrt helper;
- config-RCE regression test in CI.

### Firewall / runtime

- firewalld `ir-ban` policy from ANY to HOST for bans across zones;
- more conservative apply/rollback behavior for local backends;
- `ban-flush` for targeted cleanup of IR Stack state;
- stronger systemd sandboxing and optional Postfix path handling;
- guardian separates auto-repair of IR units from alert-only monitoring of auditd/Postfix/Fail2Ban.

### Tooling

- `irctl ssh-baseline-show` and `irctl ssh-baseline-accept`;
- CI extended to firewall drivers, OpenWrt POSIX scripts, and the standalone installer;
- `persist-credentials: false` in GitHub Actions checkout;
- `SECURITY-REVIEW_ENG.md` documents findings, remediation, and residual risks.

## 0.2.0-dev

- GPL-3.0-or-later and Dascos copyright.
- Multiple `TRUSTED_SOURCES` supporting IPv4/IPv6 addresses and CIDRs.
- Modular nftables, iptables, and firewalld lockdown backends without global flushes.
- `ir-ban` dispatcher with local/OpenWrt backends.
- Remote OpenWrt integration using forced-command and banIP/nftables fw4 fallback.
- Optional Fail2Ban action.
- OpenWrt bootstrap with Ed25519 key and host-key pinning.

## 0.1.0

- refactor of the standalone baseline published on SicurezzaReti;
- interactive and unattended installer;
- mail modes: existing / postfix-relay / none;
- maintenance window;
- SSH login polling through journald timer;
- dynamic auditing of existing `authorized_keys`;
- uninstall, doctor, and mail-test commands;
- standalone installer build;
- ShellCheck CI.
