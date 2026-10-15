#!/bin/bash
# Build an OpenArena compatible Quake3e: clone upstream Quake3e at a pinned
# commit, apply the patches in patches/, build Linux and Windows binaries
# and collect them in dist/.
#
# Usage: ./build.sh [--linux-only] [--clean] [--jobs N]
#
# Environment overrides:
#   QUAKE3E_REPO       git URL to clone      (default: https://github.com/ec-/Quake3e.git)
#   QUAKE3E_REFERENCE  local Quake3e clone used with --reference-if-able to
#                      speed up the clone    (default: /home/poul/programmering/git/Quake3e)
#   QUAKE3E_COMMIT     upstream commit the patches are made for

set -euo pipefail

QUAKE3E_REPO="${QUAKE3E_REPO:-https://github.com/ec-/Quake3e.git}"
QUAKE3E_REFERENCE="${QUAKE3E_REFERENCE:-/home/poul/programmering/git/Quake3e}"
QUAKE3E_COMMIT="${QUAKE3E_COMMIT:-3173cef096dd0cb2fea26d91bce71049061f5a13}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/build/Quake3e"
DIST="$HERE/dist"
PATCHES="$HERE/patches"

BUILD_WINDOWS=1
CLEAN=0
JOBS="$(nproc 2>/dev/null || echo 4)"

while [ $# -gt 0 ]; do
	case "$1" in
		--linux-only) BUILD_WINDOWS=0 ;;
		--clean) CLEAN=1 ;;
		--jobs) JOBS="$2"; shift ;;
		-j*) JOBS="${1#-j}" ;;
		-h|--help) sed -n '2,14p' "$0"; exit 0 ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
	shift
done

die() { echo "error: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing tool: $1"; }

echo "== checking tools"
need git; need make; need gcc; need pkg-config
pkg-config --exists sdl2 || die "SDL2 development files not found (apt install libsdl2-dev)"
[ -e /usr/include/curl/curl.h ] || [ -e /usr/include/x86_64-linux-gnu/curl/curl.h ] || die "curl headers not found (apt install libcurl4-openssl-dev)"
if [ "$BUILD_WINDOWS" = 1 ]; then
	need x86_64-w64-mingw32-gcc
	need x86_64-w64-mingw32-windres
	need curl; need sha256sum; need tar
fi

if [ "$CLEAN" = 1 ]; then
	echo "== cleaning build/ and dist/"
	rm -rf "$HERE/build" "$DIST"
fi

echo "== preparing source at $SRC"
if [ ! -d "$SRC/.git" ]; then
	mkdir -p "$HERE/build"
	if [ -d "$QUAKE3E_REFERENCE/.git" ]; then
		git clone --reference-if-able "$QUAKE3E_REFERENCE" "$QUAKE3E_REPO" "$SRC"
	else
		git clone "$QUAKE3E_REPO" "$SRC"
	fi
fi
if ! git -C "$SRC" cat-file -e "$QUAKE3E_COMMIT^{commit}" 2>/dev/null; then
	git -C "$SRC" fetch origin
fi
# The clone is disposable; the patches are the source of truth.
git -C "$SRC" am --abort 2>/dev/null || true
git -C "$SRC" checkout -q -B oa "$QUAKE3E_COMMIT"
git -C "$SRC" reset -q --hard "$QUAKE3E_COMMIT"

echo "== applying patches"
git -C "$SRC" am --3way "$PATCHES"/*.patch
git -C "$SRC" log --oneline "$QUAKE3E_COMMIT..HEAD"

echo "== building Linux x86_64"
make -C "$SRC" -j"$JOBS" release
LIN="$SRC/build/release-linux-x86_64"
mkdir -p "$DIST/linux-x86_64"
cp "$LIN/openarena.x86_64" "$LIN/oa_ded.x86_64" "$LIN"/openarena_*_x86_64.so "$DIST/linux-x86_64/"

if [ "$BUILD_WINDOWS" = 1 ]; then
	# The bundled static libcurl needs zlib. Use the system mingw zlib when
	# installed (libz-mingw-w64-dev), otherwise build a static one from the
	# pinned zlib release and put it next to the bundled libcurl.a.
	if ! ls /usr/x86_64-w64-mingw32/lib/libz.a /usr/x86_64-w64-mingw32/lib/libz.dll.a >/dev/null 2>&1; then
		ZLIB_VERSION=1.3.1
		ZLIB_SHA256=9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23
		ZLIB_DIR="$HERE/build/zlib-mingw64"
		if [ ! -f "$ZLIB_DIR/libz.a" ]; then
			echo "== building static zlib $ZLIB_VERSION for mingw64 (no libz-mingw-w64-dev installed)"
			rm -rf "$ZLIB_DIR"; mkdir -p "$ZLIB_DIR"
			curl -sSL -o "$ZLIB_DIR/zlib.tar.gz" "https://zlib.net/fossils/zlib-$ZLIB_VERSION.tar.gz"
			echo "$ZLIB_SHA256  $ZLIB_DIR/zlib.tar.gz" | sha256sum -c - >/dev/null || die "zlib download checksum mismatch"
			tar -xzf "$ZLIB_DIR/zlib.tar.gz" -C "$ZLIB_DIR"
			make -C "$ZLIB_DIR/zlib-$ZLIB_VERSION" -f win32/Makefile.gcc PREFIX=x86_64-w64-mingw32- libz.a >/dev/null
			cp "$ZLIB_DIR/zlib-$ZLIB_VERSION/libz.a" "$ZLIB_DIR/libz.a"
		fi
		cp "$ZLIB_DIR/libz.a" "$SRC/code/libcurl/windows/mingw/lib64/libz.a"
	fi

	echo "== building Windows x86_64"
	make -C "$SRC" -j"$JOBS" PLATFORM=mingw64 ARCH=x86_64 release
	WIN="$SRC/build/release-mingw64-x86_64"
	mkdir -p "$DIST/windows-x86_64"
	cp "$WIN/openarena.x86_64.exe" "$WIN/oa_ded.x86_64.exe" "$WIN"/openarena_*_x86_64.dll "$WIN/SDL264.dll" "$DIST/windows-x86_64/"
fi

echo "== done, binaries in $DIST:"
find "$DIST" -type f | sort
