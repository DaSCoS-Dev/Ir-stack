#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/install-common.sh
. "$ROOT_DIR/lib/install-common.sh"

# Installation phases are sourced deliberately so they share installer state
# and positional arguments without turning runtime configuration into shell code.
# shellcheck source=lib/install-phase-config.sh
. "$ROOT_DIR/lib/install-phase-config.sh"
# shellcheck source=lib/install-phase-system.sh
. "$ROOT_DIR/lib/install-phase-system.sh"
# shellcheck source=lib/install-phase-deploy.sh
. "$ROOT_DIR/lib/install-phase-deploy.sh"
