# Migrazione dalla baseline dell'articolo

La baseline pubblicata nell'articolo usa:

- `/etc/incident-response/lockdown.conf`;
- `/etc/incident-response/identity-shell-whitelist`;
- unità `identity-*`, `ssh-login-alert.*`, `ir-stack-watch.*`, `ir-guardians-watchdog.*`;
- trigger SSH basato su `/var/log/auth.log`;
- whitelist `asterisk` hardcoded;
- trusted IPv4 richiesto già in fase di installazione;
- configurazione generata come frammento shell.

Il repository installa invece sotto `/etc/ir-stack`, usa unità con prefisso `ir-stack-*`, config `KEY=VALUE` non eseguibile, trusted source multiple, audit rules dinamiche e baseline degli `authorized_keys`.

Per una macchina che esegue già la baseline dell'articolo è consigliato:

1. salvare `/etc/incident-response`, audit rules e unità systemd;
2. verificare e annotare email, trusted source, porta SSH e whitelist;
3. disabilitare le vecchie unità senza rimuovere subito file e log;
4. installare la nuova versione;
5. eseguire `irctl doctor`, `irctl check`, `irctl mail-test`;
6. controllare `irctl ssh-baseline-show` e accettare la baseline soltanto se le chiavi presenti sono attese;
7. verificare `auditctl -s` e `irctl audit`; se auditd è immutable può essere necessario un reboot;
8. testare manualmente eventuale lockdown + rollback da console;
9. solo dopo rimuovere i vecchi file.

La rc1 non migra automaticamente le personalizzazioni della baseline articolo: interpretare automaticamente configurazioni root storiche sarebbe più rischioso che richiedere una migrazione esplicita.
