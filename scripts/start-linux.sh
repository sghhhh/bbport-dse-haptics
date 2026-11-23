#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
appimage=$(realpath -- "${1:?pass the official linux-seamless-beta.1 AppImage path}")
shift
if [[ ! -x $appimage || ! -x $root/bin/bb-probe ]]; then
    echo 'The official AppImage and the extracted DSE engine must be executable.' >&2
    exit 1
fi
export BB_PROBE="$root/bin/bb-probe"
exec "$appimage" "$@"
