# Fail2Ban

L'integrazione è opzionale. L'installer può installare `/etc/fail2ban/action.d/ir-stack.conf`, ma **non abilita alcuna jail automaticamente**.

In una jail esistente:

```ini
banaction = ir-stack
```

L'action chiama:

```text
/usr/local/sbin/ir-ban add <ip>
/usr/local/sbin/ir-ban del <ip>
```

Il routing del ban è definito da `BAN_BACKENDS`:

- `local`: backend firewall locale rilevato/configurato;
- `openwrt`: solo router OpenWrt remoto;
- `local,openwrt`: enforcement immediato locale + enforcement sul bordo.

Le trusted sources non vengono mai bannate da `ir-ban`.
