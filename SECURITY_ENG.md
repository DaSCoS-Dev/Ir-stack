# Security policy

[Italiano](SECURITY.md) | **English**

IR Stack runs with root privileges and modifies audit rules, systemd units, and, when explicitly enabled, the firewall.

To report a vulnerability in the project, avoid opening public issues containing working exploits or real secrets. Start with a private report to the repository maintainer.

Never include the following in bug reports:

- SMTP passwords;
- administrative IP addresses that are not intended for publication;
- logs containing credentials or tokens;
- private SSH keys.
