# Firewall backends

[Italiano](firewall-backends.md) | **English**

IR Stack separates **emergency lockdown** from **dynamic bans**.

## Local lockdown

`FIREWALL_BACKEND=auto|nftables|iptables|firewalld|none`.

- `nftables`: creates a separate `inet ir_stack_lockdown` table. It does not flush the existing ruleset and applies the IR ruleset atomically.
- `iptables`: uses a dedicated `IR_STACK_LOCKDOWN` chain and inserts it at the top of INPUT. It does not flush existing chains; if apply fails, it removes the IR objects created during that attempt.
- `firewalld`: creates a runtime `ir-lockdown` policy from `ANY` to `HOST`, with negative priority and DROP target; if an error occurs while building it, the partial policy is removed.
- `auto`: prefers firewalld when active, then an already operational nftables environment, then iptables; on new hosts it may choose nftables.

Rollback removes only objects created by IR Stack.

### Already established connections

The default is:

```ini
LOCKDOWN_KEEP_ESTABLISHED="no"
```

Therefore nftables/iptables do not automatically add an `ESTABLISHED,RELATED` rule. If set to `yes`, existing sessions are preserved.

Actual connection-tracking behavior must still be tested on the real backend. Firewalld in particular is a higher-level management layer: do not assume that every already tracked state will be terminated exactly like it is with the dedicated nftables/iptables drivers.

## Multiple trusted sources

`TRUSTED_SOURCES` accepts individual IPv4/IPv6 addresses and CIDRs separated by commas, semicolons, or whitespace:

```ini
TRUSTED_SOURCES="192.168.2.43,10.0.10.98,10.0.20.0/24,2001:db8:10::/64"
```

Addresses are validated/canonicalized. `ir-ban` explicitly refuses to ban an IP that belongs to a trusted source.

## Dynamic bans

`BAN_BACKENDS=local`, `openwrt`, or `local,openwrt`.

`ir-ban add 203.0.113.44` and `ir-ban del 203.0.113.44` are the integration point for Fail2Ban and future detectors.

Local backends:

- nftables: dedicated sets in the IR Stack table;
- iptables: dedicated `IR_STACK_BAN` chain;
- firewalld: `ir-ban` policy from `ANY` to `HOST`, target `CONTINUE`, with rich DROP rules for banned IPs.

`ban-flush` removes only IR Stack dynamic state for the selected backend.

## Operational safety rule

Do not set `ENABLE_LOCKDOWN=yes` on a server class before testing **apply and rollback from console/out-of-band access**. Lockdown is a containment mechanism and may interrupt legitimate services exactly as designed.
