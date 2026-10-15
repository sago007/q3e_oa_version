#!/bin/bash
# Regenerate patches/ from the commits on top of the pinned Quake3e commit
# in build/Quake3e. Workflow: edit and commit in build/Quake3e, run this,
# then commit the updated patches in this repository.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HERE/build/Quake3e"
QUAKE3E_COMMIT="${QUAKE3E_COMMIT:-$(sed -n 's/^QUAKE3E_COMMIT="\${QUAKE3E_COMMIT:-\([0-9a-f]*\)}"$/\1/p' "$HERE/build.sh")}"
[ -d "$SRC/.git" ] || { echo "no clone at $SRC, run ./build.sh first" >&2; exit 1; }
[ -n "$QUAKE3E_COMMIT" ] || { echo "could not determine QUAKE3E_COMMIT" >&2; exit 1; }
rm -f "$HERE"/patches/*.patch
git -C "$SRC" format-patch --binary -N -o "$HERE/patches" "$QUAKE3E_COMMIT..HEAD"
ls -1 "$HERE/patches"
