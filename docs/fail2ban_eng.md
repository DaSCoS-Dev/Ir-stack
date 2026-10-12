# Fail2Ban

[Italiano](fail2ban.md) | **English**

The integration is optional. The installer can install `/etc/fail2ban/action.d/ir-stack.conf`, but **does not automatically enable any jail**.

In an existing jail:

```ini
banaction = ir-stack
```

The action calls:

```text
/usr/local/sbin/ir-ban add <ip>
/usr/local/sbin/ir-ban del <ip>
```

Ban routing is defined by `BAN_BACKENDS`:

- `local`: detected/configured local firewall backend;
- `openwrt`: remote OpenWrt router only;
- `local,openwrt`: immediate local enforcement + edge enforcement.

Trusted sources are never banned by `ir-ban`.
