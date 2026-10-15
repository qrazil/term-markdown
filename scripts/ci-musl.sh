#!/bin/sh
# Alpine / musl release build: run INSIDE an alpine container with the repo
# mounted as the working directory (see .github/workflows/release.yml):
#
#   docker run --rm -e M31_MUSL_REF -e GITHUB_SHA -e GITHUB_REF_NAME \
#     -v "$PWD:/w" -w /w alpine:3.22 sh scripts/ci-musl.sh
#
# Downloads the m31 musl release (static compiler + runtime SDK), builds the
# programs with it and Alpine's own cc, smoke-runs them, and writes
# markdown-linux-<arch>-musl.tar.gz with the same layout as the glibc tarballs.
# It runs as a plain `docker run`, not a job container: the JS actions
# (checkout, upload-artifact) need glibc node on the host.
set -eu
cd "$(dirname "$0")/.."

: "${M31_MUSL_REF:?M31_MUSL_REF is not set}"
# bash + GNU tools: scripts/build.sh is bash; git: m31c fetches `deps` with it.
apk add --no-cache bash curl tar gzip git coreutils sed grep gawk gcc musl-dev linux-headers >/dev/null
git config --global --add safe.directory "*"

arch=$(uname -m)
case "$arch" in arm64) arch=aarch64 ;; esac

M31_DIR=${M31_DIR:-/opt/m31}
mkdir -p "$M31_DIR"
curl -fsSL "https://github.com/qrazil/m31/releases/download/$M31_MUSL_REF/m31-linux-$arch-musl.tar.gz" |
    tar -C "$M31_DIR" -xzf -
chmod +x "$M31_DIR/m31c"
export LANGC="$M31_DIR/m31c" M31_ROOT="$M31_DIR"

OUT="dist/markdown-linux-$arch-musl"
rm -rf dist
mkdir -p "$OUT"
OUT="$OUT/markdown" bash scripts/build.sh
cp README.md docs/FRICTION.md "$OUT/" 2>/dev/null || true
cat >"$OUT/NOTES.txt" <<EOF
markdown - Linux $arch (musl / Alpine) release build
Built from commit: ${GITHUB_SHA:-unknown}
Tag: ${GITHUB_REF_NAME:-unknown}
Built against m31 $M31_MUSL_REF

markdown README.md                       the HTML fragment, on stdout
markdown --full --title T in.md --out f  a whole document, to a file
markdown                                 reads standard input
markdown --help
EOF

# Smoke: run what was just built, in this container.
[ "$(printf '# hi\n' | "$OUT/markdown")" = "<h1>hi</h1>" ]

tar -C "$OUT" -czf "markdown-linux-$arch-musl.tar.gz" .
ls -l "markdown-linux-$arch-musl.tar.gz"
