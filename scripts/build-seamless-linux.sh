#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
cd -- "${1:?pass the patched Linux beta engine source directory}"
if [[ ! -f src/runtime_dse_haptics.c ]]; then
    echo 'Apply patches/seamless-linux-dse-haptics.patch to the pinned Linux engine source first.' >&2
    exit 1
fi
export BB_PGO=off BB_LTO=OFF
export BB_SEAMLESS_REVISION=${BB_SEAMLESS_REVISION:-bbsc100-p198-dse8-linux}
exec bash build.sh
