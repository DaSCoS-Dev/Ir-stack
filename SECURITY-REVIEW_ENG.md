# Security review - 0.2.0-rc1

[Italiano](SECURITY-REVIEW.md) | **English**

This review compares the `0.2.0-dev` baseline with release candidate `0.2.0-rc1`.
The goal is not to prove that IR Stack is "secure by definition", but to remove avoidable failure modes before publication and make residual risks explicit.

## Summary

| Severity | Finding | Status in rc1 |
|---|---|---|
| HIGH | configuration files executed through `source` as root | FIXED |
| HIGH | uninstall could remove rollback tooling before using it | FIXED |
| HIGH | OpenWrt bootstrap verified one host key but could save multiple keys | FIXED |
| HIGH | audit rules could fail or remain incomplete without failing installation | FIXED |
| MEDIUM/HIGH | lockdown always preserved `ESTABLISHED,RELATED` | FIXED, now opt-in |
| MEDIUM | SSH cursor could be lost or overwritten with empty state | FIXED |
| MEDIUM | firewalld bans limited to the default zone | FIXED |
| MEDIUM | SSH baseline could be implicitly accepted during reinstall/update | FIXED |
| MEDIUM | systemd units could fail without Postfix because of a missing `ReadWritePaths` path | FIXED |
| MEDIUM | authenticated SMTP allowed opportunistic TLS | FIXED |
| MEDIUM | watchdog did not distinguish IR services from external dependencies | FIXED/MITIGATED |
| MEDIUM | CI did not cover every firewall driver and OpenWrt POSIX script | FIXED |
| LOW/MEDIUM | weak semantic IP validation in the OpenWrt backend | FIXED |
| LOW | duplicate SPDX headers / CI hygiene | FIXED |

## SR-01 - Configuration executable as root

**Severity:** HIGH  
**Affected version:** 0.2.0-dev

### Problem

Installer and runtime loaded configuration files with `source`/`.`. A line such as:

```text
ALERT_EMAIL="$(command)"
```

could therefore become code execution with root privileges.

### Fix

rc1 uses a data-only `KEY=VALUE` parser with an allowlist of supported keys. Values are not evaluated by the shell. Unknown keys are rejected.

The regression test in `tests/smoke.sh` verifies that a configuration containing `$(touch ...)` remains inert data.

### Operational note

Configuration files **do not support inline comments**. Use separate comment lines beginning with `#`.

---

## SR-02 - Rollback removed too early during uninstall

**Severity:** HIGH  
**Affected version:** 0.2.0-dev

### Problem

`uninstall.sh` could delete `emergency-lockdown-rollback.sh` before executing rollback. If lockdown was active, the host could remain isolated while the recovery tool itself was being removed.

### Fix

rc1 performs rollback and best-effort cleanup of IR Stack objects in all three local backends first, then removes binaries and configuration.

Uninstall does not remove system packages, Postfix, or the remote OpenWrt helper.

---

## SR-03 - Incomplete OpenWrt host-key verification

**Severity:** HIGH  
**Affected version:** 0.2.0-dev

### Problem

Bootstrap displayed the fingerprint of one host key but could save multiple keys returned by `ssh-keyscan`. An unconfirmed key could therefore enter the dedicated `known_hosts` file.

### Fix

rc1 selects exactly one host key, calculates the fingerprint for that exact line, and stores only that key. In non-interactive mode, `--host-key SHA256:...` is mandatory.

Interactive mode remains TOFU unless the administrator compares the fingerprint through an independent channel.

---

## SR-04 - Incomplete audit coverage and hidden failures

**Severity:** HIGH  
**Affected version:** 0.2.0-dev

### Problem

Static audit rules could reference missing files or binaries; additionally, `augenrules --load || true` allowed the installer to report success even when rules had not loaded correctly.

### Fix

`refresh-audit-rules.sh` generates rules only for objects that actually exist, covers existing `.ssh` directories as well as `authorized_keys`, and makes normal `augenrules` failures blocking.

If auditd is in immutable mode (`enabled=2`), a specific status is returned: the new configuration will take effect after reboot and the installer reports this explicitly.

---

## SR-05 - Lockdown preserved existing sessions

**Severity:** MEDIUM/HIGH  
**Affected version:** 0.2.0-dev

### Problem

Lockdown always allowed `ESTABLISHED,RELATED`. A hostile connection that was already active could therefore continue after isolation.

### Fix

The default is now:

```ini
LOCKDOWN_KEEP_ESTABLISHED="no"
```

Preserving existing sessions must be explicitly selected. Effective behavior must still be tested against the host's firewall backend and connection tracking.

---

## SR-06 - Fragile SSH journald cursor

**Severity:** MEDIUM

### Fix

The cursor is updated atomically and is not replaced by an empty state. An invalid cursor or unreadable journal produces a warning, an alert attempt, and explicit reinitialization instead of silently continuing.

---

## SR-07 - Firewalld ban applied only to the default zone

**Severity:** MEDIUM

### Fix

Dynamic firewalld bans use a dedicated `ir-ban` policy from `ANY` to `HOST`, with target `CONTINUE` and rich DROP rules for banned addresses. Enforcement no longer depends on the interface's default zone.

---

## SR-08 - SSH baseline implicitly accepted

**Severity:** MEDIUM

### Problem

Automatically regenerating the baseline during an update could turn a hostile change already present on the system into the new "normal" state.

### Fix

The baseline is created only when absent. An existing baseline is not overwritten during reinstall/update. After an authorized change, the administrator must deliberately run:

```bash
irctl ssh-baseline-accept
```

---

## SR-09 - systemd sandbox depended on Postfix

**Severity:** MEDIUM

### Fix

Optional paths such as `/var/spool/postfix` use the systemd `-` prefix, so the absence of Postfix does not prevent watchers from starting.

Units also use `ProtectSystem=strict`, `NoNewPrivileges=yes`, address-family restrictions, and other hardening compatible with each service's role.

---

## SR-10 - Authenticated SMTP with opportunistic TLS

**Severity:** MEDIUM

### Fix

`RELAY_TLS_MODE=verify|encrypt|may|none` was introduced. When `RELAY_AUTH=yes`, the installer rejects `may` and `none`. Passwords can be supplied through a file to avoid shell history/process listings and are not stored in `ir-stack.conf`.

---

## SR-11 - Watchdog and external services

**Severity:** MEDIUM

### Fix

Internal IR Stack units are auto-repaired. `auditd`, stack-managed Postfix, and Fail2Ban are monitored in alert-only mode instead: IR Stack does not automatically restart an external service and therefore does not hide its failure mode.

### Accepted residual risk

A local watchdog cannot guarantee detection if a root attacker disables its own timer. Strong guarantees require external/out-of-band monitoring.

---

## SR-12 - SSH-key coverage beyond auditd

**Severity:** MEDIUM

rc1 adds a small, deterministic inventory of existing `authorized_keys`: path, SHA256, UID/GID, and mode. The checker compares it against an explicitly accepted baseline. This also covers creations/removals that could escape a watch tied to a file that did not exist at installation time.

Auditd remains the forensic context source; the baseline does not replace it.

---

## SR-13 - OpenWrt remote helper and trusted sources

**Residual severity:** MEDIUM

The local `ir-ban` dispatcher prevents banning addresses covered by `TRUSTED_SOURCES`. The OpenWrt forced-command limits the key to `check/status/ban/unban`, but the router does not yet hold an independent copy of the trusted allowlist.

Consequence: a compromised root account on the IR host that possesses the dedicated key could call the forced command directly and attempt to ban a management source.

**rc1 decision:** documented risk, not blocking for the release candidate. Recommended hardening for a later release: synchronize trusted sources to the router and reject them in the OpenWrt helper as well.

---

## SR-14 - Firewalld and already tracked connections

**Residual severity:** LOW/MEDIUM

Isolation semantics must be verified against the actual firewall and connection tracking. `LOCKDOWN_KEEP_ESTABLISHED=no` expresses the stack's intent, but a higher-level backend such as firewalld may interact with already tracked state differently from the dedicated nftables/iptables drivers.

**Recommendation:** test lockdown + rollback from console on every host class before setting `ENABLE_LOCKDOWN=yes`.

---

## SR-15 - Installation is not fully transactional

**Residual severity:** LOW/MEDIUM

The installer creates backups and records an `INSTALL_FAILED` marker on error. It does not attempt a broad automatic rollback of packages, MTA, and every external configuration because an aggressive automated rollback could cause more damage than the partial state.

**Decision:** explicit, conservative behavior. Use a VM/staging environment before production and preserve console access.

---

## CI and supply chain

rc1 extends checks to:

- all Bash scripts;
- firewall drivers;
- OpenWrt POSIX scripts;
- standalone installer build;
- execution of `--help` on the generated installer;
- regression test for the non-executable configuration parser.

`actions/checkout` is pinned to full commit SHA `3d3c42e5aac5ba805825da76410c181273ba90b1` (tag `v7`) with `persist-credentials: false`. Dependabot for GitHub Actions is enabled.

## Result

The HIGH findings identified in `0.2.0-dev` are fixed in `0.2.0-rc1`. Residual risks are documented and mainly concern architectural limits or behavior that must be tested in the real environment: firewall/connection tracking, local observer limitations, remote OpenWrt allowlisting, and installation that is not fully transactional.
