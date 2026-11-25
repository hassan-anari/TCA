#!/usr/bin/env bash
# Rebuilds every runtime asset in assets/models and assets/env from source.
#
# Requirements:
#   - python3 with numpy + Pillow           (procedural textures / HDR)
#   - Blender 4.2+ on PATH                   (verified: Blender 4.3.2)
#   - Filament v1.77.2 `cmgen` (same release Thermion 0.7.0 links against).
#     Set CMGEN=/path/to/cmgen. On non-x86_64 hosts it can run under
#     qemu-user, e.g. CMGEN="qemu-x86_64 -L /usr/x86_64-linux-gnu /opt/filament/bin/cmgen".
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HERE="$ROOT/tools/assets"
CMGEN="${CMGEN:-cmgen}"
PY="${PYTHON:-python3}"

"$PY" "$HERE/generate_textures.py"
blender -b --factory-startup -P "$HERE/generate_models.py" -- "$ROOT/assets/models"

cd "$HERE/build"
rm -rf env sky
# Prefiltered IBL (reflections cubemap + spherical harmonics), 256px faces.
$CMGEN --format=ktx --size=256 --deploy=env nebula_equirect.hdr
# Skybox only (no prefiltering), 512px faces.
$CMGEN --format=ktx --size=512 --extract=sky nebula_equirect.hdr
mkdir -p "$ROOT/assets/env"
cp env/env_ibl.ktx "$ROOT/assets/env/nebula_ibl.ktx"
cp sky/sky_skybox.ktx "$ROOT/assets/env/nebula_skybox.ktx"
echo "assets rebuilt"
