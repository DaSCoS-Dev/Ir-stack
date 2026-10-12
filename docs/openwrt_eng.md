# Remote OpenWrt

[Italiano](openwrt.md) | **English**

The integration uses a dedicated Ed25519 key and a forced-command on the router. The key does not receive a generic shell: the wrapper accepts only `check`, `status`, `ban IP`, and `unban IP`.

## Bootstrap

From the IR Stack checkout:

```bash
./scripts/bootstrap-openwrt.sh --host 192.168.1.1
```

Bootstrap:

1. generates a dedicated Ed25519 key if one does not already exist;
2. retrieves a single host key and displays its fingerprint for verification;
3. stores **only the confirmed key** in the dedicated `known_hosts` file;
4. installs the helper and wrapper on the router;
5. adds the public key to `/etc/dropbear/authorized_keys` with `restrict` + `command=`;
6. verifies the forced-command with `check`.

### Host-key verification

Interactive mode is TOFU if you simply confirm the displayed fingerprint. The correct procedure is to compare it through an independent channel, for example the router console or an already trusted inventory.

For unattended use, the expected fingerprint is mandatory:

```bash
./scripts/bootstrap-openwrt.sh \
  --host 192.168.1.1 \
  --non-interactive \
  --host-key 'SHA256:...'
```

## Router backend

If `/usr/bin/f2b-banip` exists, the dispatcher reuses the banIP integration (`sync-add` / `sync-del`). Otherwise it installs a persistent nftables fallback through firewall4's `ruleset-post` drop-in, with a separate `inet ir_stack_edge` table and IPv4/IPv6 sets.

The fallback does not modify existing UCI/fw4 chains and is regenerated with the ruleset through the fw4 include.

IPs received by the forced-command are semantically validated with `nft -c` before use.

## Important limitation: trusted sources on the router

The normal flow goes through `ir-ban`, which rejects addresses belonging to `TRUSTED_SOURCES` before sending the command to the router.

In rc1, the router **does not yet hold an independent copy of this allowlist**. A compromised root account on the IR host that possesses the dedicated key could therefore attempt to invoke the forced command directly with a management IP.

For this reason:

- the OpenWrt key must be root-only;
- the forced-command remains limited to ban operations;
- maintaining alternative/out-of-band management access is recommended;
- a later release should synchronize trusted sources to the router and enforce rejection on the OpenWrt side as well.
