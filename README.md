# OpenArena build of Quake3e

Patches and a build script that turn upstream [Quake3e](https://github.com/ec-/Quake3e)
into an engine compatible with OpenArena 0.8.8 (game data in `baseoa`, protocol 71,
OpenArena master server, `~/.local/share/OpenArena` home directory, OpenArena icons).

The engine source is never stored here. `build.sh` clones Quake3e at a pinned
commit, applies `patches/*.patch` with `git am`, builds, and collects the binaries
in `dist/`.

## Prerequisites (Ubuntu/Debian)

    sudo apt install build-essential git make pkg-config libsdl2-dev libcurl4-openssl-dev
    # Windows cross build:
    sudo apt install gcc-mingw-w64-x86-64 binutils-mingw-w64-x86-64
    # optional, otherwise build.sh builds a static zlib from source for the Windows curl link:
    sudo apt install libz-mingw-w64-dev

## Usage

    ./build.sh                # Linux x86_64 + Windows x86_64
    ./build.sh --linux-only   # skip the mingw build
    ./build.sh --clean        # wipe build/ and dist/ first
    ./build.sh --jobs 8

Environment overrides: `QUAKE3E_REPO`, `QUAKE3E_COMMIT` (the pinned upstream commit
the patches apply to), `QUAKE3E_REFERENCE` (a local Quake3e clone used to speed up
cloning).

### Docker

To build without installing the toolchain, `Dockerfile` runs `build.sh` in an
Ubuntu 22.04 container and exports the binaries:

    DOCKER_BUILDKIT=1 docker build -o dist-docker .          # both platforms
    DOCKER_BUILDKIT=1 docker build -o dist-docker --build-arg BUILD_ARGS=--linux-only .

Build args: `QUAKE3E_COMMIT`, `JOBS`, `BUILD_ARGS` (extra `build.sh` options).
`--target build` keeps the toolchain image with the full build tree in `/src`.

Output:

    dist-docker/linux-x86_64/   openarena.x86_64  oa_ded.x86_64  openarena_opengl_x86_64.so  openarena_vulkan_x86_64.so
    dist-docker/windows-x86_64/ openarena.x86_64.exe  oa_ded.x86_64.exe  openarena_opengl_x86_64.dll  openarena_vulkan_x86_64.dll  SDL264.dll

Copy the files for your platform into an OpenArena 0.8.8 installation (next to
`baseoa/`) and run `openarena.x86_64` / `openarena.x86_64.exe`. The renderer
libraries must sit next to the executable.

## What the patches do

| Patch | Change |
|---|---|
| 0001 | `STANDALONE` build (no CD key / authorize server / id pak checksum check), `BASEGAME "baseoa"`, window title and version string, default `protocol 71-compat`, master server `dpmaster.deathmask.net` only |
| 0002 | XDG home directory on Linux: `$XDG_DATA_HOME/OpenArena` or `~/.local/share/OpenArena`, with migration of an existing `~/.openarena` and a compatibility symlink (ported from the OpenArena engine) |
| 0003 | `%APPDATA%\OpenArena` home directory on Windows |
| 0004 | OpenArena window icon and Windows executable icon, plus `misc/openarena.png` and `misc/openarena.svg` |
| 0005 | `r_fbo` defaults to 1 so `r_bloom 1` works |
| 0006 | Binary names `openarena.x86_64`, `oa_ded.x86_64`, `openarena_<renderer>_x86_64` |
| 0007 | OpenArena text colours: `^0`-`^8` with `^8` orange, other `^x` sequences print literally (Quake3e's extended `^9`/`^a`-`^z` colours are disabled) |
| 0008 | OpenArena cgame syscalls 112 (`trap_R_LFX_ParticleEffect`) and 113 (`trap_R_GetViewPosition`) reserved as stubs; Quake3e's own cgame extensions move to 120+ (mods find them via `trap_GetValue`) |
| 0009 | OpenArena's renderer particle system (`tr_particles.c`, "LFX") and `GetViewPosition` ported into the OpenGL and Vulkan renderers; world collision for particles through two new refimport entries, `r_particles` selects the effect set |

### Protocol

OpenArena's protocol 71 is the classic Quake 3 (68-style) netchan with ioquake3's
challenge format. Quake3e implements exactly that as `protocol 71-compat`, which
these builds use by default. Quake3e peers still negotiate Quake3e's own protocol 71
features among themselves. Demos are recorded as `.dm_71`.

### Bloom

Bloom comes from Quake3e's own FBO-based implementation, available in both the
OpenGL and Vulkan renderers. `r_bloom 1` enables it. OpenArena's bloom cvars
(`r_bloom_alpha`, `r_bloom_darken`, `r_bloom_sample_size`, `r_bloom_cascade*`, ...)
are ignored; `r_bloom_intensity` exists in both engines but has different
semantics (Quake3e default 0.5). See Quake3e's `r_bloom_threshold`,
`r_bloom_passes`, `r_bloom_filter_size` and `r_bloom_modulate`.

### Not ported from the OpenArena engine

OpenArena's renderer extras (GLSL post-processing, lens reflections, `r_specMode`,
`r_envMode`) and its console cosmetics are not part of this build. Quake3e's own
equivalents apply. The extra `refEntity_t` fields of newer OpenArena gamecode (eye
tracking, glow) are ignored.

### Particles

The OpenArena renderer particle system is included in both renderers. The gamecode
turns it on with `cg_leiEnhancement 1`; `r_particles` picks the effect set (0 default,
1996-1999 the retro sets, as in OpenArena). The particle shaders (`psmoke-*`, `pball-*`,
`pshock-*`, `pblood1`, `pwater*`, `pfireball`) are mod data, currently shipped as
`scripts/placeholder_particles.shader` in `oax_m`; without them nothing is drawn.

## Maintaining the patches

`build/Quake3e` is a disposable clone with the patches applied as commits on the
`oa` branch. To change something:

1. Edit and commit (or amend) in `build/Quake3e`.
2. `./tools/export-patches.sh` regenerates `patches/` from the commits above the
   pinned commit.
3. Commit the updated patches in this repository.

To move to a newer Quake3e, change `QUAKE3E_COMMIT` in `build.sh`, run
`./build.sh --clean`, resolve any `git am` conflicts in `build/Quake3e`, and
re-export the patches.
