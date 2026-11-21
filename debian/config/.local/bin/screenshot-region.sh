#!/usr/bin/env bash
set -Eeuo pipefail
geometry="$(slurp)" || exit 0
[[ -n "$geometry" ]] || exit 0
grim -g "$geometry" - | wl-copy --type image/png
