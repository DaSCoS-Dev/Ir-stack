# Architecture

[Italiano](architecture.md) | **English**

```text
identity files ---> path/timer ---> checker ---> incident handler ---> mail/log
                         |             |                  |
                         |             |                  +--> lockdown dispatcher
                         |             |                         + nftables
                         |             |                         + iptables
                         |             |                         + firewalld
                         |             |
                         |             +--> SSH-key baseline diff
                         |
                         +--> dynamic audit rules

Fail2Ban / detector ---> ir-ban --------------------------> local firewall ban
                                                       +--> forced SSH ---> OpenWrt edge

journald/sshd ---> cursor parser ---> mail/log
IR files -------> self-watch ------> mail/log
systemd units --> guardians -------> auto-repair IR units / alert external deps
maintenance marker (/run/ir-stack/maintenance.until)
```

## Principles

- Detection, lockdown, and dynamic bans are separate mechanisms.
- Lockdown is opt-in and does not flush the existing firewall.
- Multiple trusted sources accept IPv4/IPv6 hosts and CIDRs.
- `ir-ban` never bans an address that belongs to trusted sources.
- Audit rules are generated only for objects that actually exist; loading failures are not hidden.
- SSH keys are monitored both through auditing of existing directories/files and through inventory/baseline comparison.
- OpenWrt uses a dedicated key with a forced-command and dedicated host-key pinning, not a generic remote shell.
- Fail2Ban is an optional producer of ban events, not a core dependency.
- IR Stack units can be auto-repaired by the guardian; important external services are only reported.

## Explicitly documented limitations

### Local observer

A watchdog running on the same host cannot guarantee detection if a root attacker disables its own timer. Strong guarantees require external monitoring.

### SSH baseline

The baseline detects divergence in a small set of sensitive files. It does not replace auditd and must be explicitly accepted after authorized changes.

### Firewall

Exact connection-tracking semantics depend on the backend and environment. Every host class must be tested from console access before automatic lockdown is enabled.
