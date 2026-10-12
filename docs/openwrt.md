# OpenWrt remoto

L'integrazione usa una chiave Ed25519 dedicata e un forced-command sul router. La chiave non ottiene una shell generica: il wrapper accetta solo `check`, `status`, `ban IP` e `unban IP`.

## Bootstrap

Dal checkout IR Stack:

```bash
./scripts/bootstrap-openwrt.sh --host 192.168.1.1
```

Il bootstrap:

1. genera una chiave Ed25519 dedicata se assente;
2. recupera una singola host key e mostra il fingerprint da verificare;
3. salva nel `known_hosts` dedicato **solo la chiave confermata**;
4. installa helper e wrapper sul router;
5. aggiunge la public key a `/etc/dropbear/authorized_keys` con `restrict` + `command=`;
6. verifica il forced-command con `check`.

### Verifica host key

La modalità interattiva è TOFU se confermi semplicemente il fingerprint mostrato. La procedura corretta è confrontarlo tramite un canale indipendente, per esempio console del router o inventario già fidato.

Per unattended è obbligatorio specificare il fingerprint atteso:

```bash
./scripts/bootstrap-openwrt.sh \
  --host 192.168.1.1 \
  --non-interactive \
  --host-key 'SHA256:...'
```

## Backend sul router

Se esiste `/usr/bin/f2b-banip`, il dispatcher riusa l'integrazione banIP (`sync-add` / `sync-del`). Altrimenti installa un fallback nftables persistente tramite il drop-in `ruleset-post` di firewall4, con tabella separata `inet ir_stack_edge` e set IPv4/IPv6.

Il fallback non modifica le chain UCI/fw4 esistenti ma viene rigenerato insieme al ruleset tramite l'include di fw4.

Gli IP ricevuti dal forced-command vengono validati semanticamente con `nft -c` prima di essere usati.

## Limitazione importante: trusted sources lato router

Il normale flusso passa da `ir-ban`, che rifiuta gli indirizzi appartenenti a `TRUSTED_SOURCES` prima di inviare il comando al router.

Il router, nella rc1, **non possiede ancora una copia autonoma di questa allowlist**. Un root compromesso sull'host IR che possiede la chiave dedicata potrebbe quindi tentare di invocare direttamente il forced command con un IP di gestione.

Per questo:

- la chiave OpenWrt deve essere root-only;
- il forced-command resta ridotto alle sole operazioni di ban;
- è consigliato mantenere accesso di gestione alternativo/out-of-band;
- una release successiva dovrebbe sincronizzare le trusted source sul router e applicare il rifiuto anche lato OpenWrt.
