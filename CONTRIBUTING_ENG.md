# Contributing

[Italiano](CONTRIBUTING.md) | **English**

Before opening a pull request:

```bash
./tests/smoke.sh
shellcheck install.sh uninstall.sh src/bin/* src/lib/*.sh scripts/*.sh tests/*.sh
```

Changes to security-related components must explain:

- the threat being addressed;
- possible false positives;
- behavior during maintenance;
- failure mode;
- rollback procedure.

## License and contribution copyright

By submitting a contribution, you confirm that you have the right to publish it under GPL-3.0-or-later. You retain copyright over your contribution; do not remove existing copyright notices and add your own notice when a substantial change requires it. Distributed derivative works must comply with GPL-3.0-or-later.
