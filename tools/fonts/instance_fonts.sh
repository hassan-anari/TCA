#!/usr/bin/env bash
# Reproducibly derives the static font weights bundled in assets/fonts from the
# official Google Fonts variable sources (SIL Open Font License 1.1).
# Requires: curl, python3 with fonttools (pip install fonttools).
set -euo pipefail
OUT="$(cd "$(dirname "$0")/../.." && pwd)/assets/fonts"
TMP="$(mktemp -d)"
curl -sSL -o "$TMP/cg.ttf" "https://github.com/google/fonts/raw/main/ofl/cormorantgaramond/CormorantGaramond%5Bwght%5D.ttf"
curl -sSL -o "$TMP/dm.ttf" "https://github.com/google/fonts/raw/main/ofl/dmsans/DMSans%5Bopsz,wght%5D.ttf"
curl -sSL -o "$OUT/OFL-CormorantGaramond.txt" "https://github.com/google/fonts/raw/main/ofl/cormorantgaramond/OFL.txt"
curl -sSL -o "$OUT/OFL-DMSans.txt" "https://github.com/google/fonts/raw/main/ofl/dmsans/OFL.txt"
for w in 400 500 600; do
  fonttools varLib.instancer "$TMP/cg.ttf" wght=$w -o "$OUT/CormorantGaramond-$w.ttf" -q
  fonttools varLib.instancer "$TMP/dm.ttf" wght=$w opsz=14 -o "$OUT/DMSans-$w.ttf" -q
done
rm -rf "$TMP"
echo "fonts written to $OUT"
