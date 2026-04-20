#!/usr/bin/env bash
# Build the Vietnamese guide into src_vi/ and stage outputs into docs/.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PACKAGE="${PACKAGE:-bgipc}"
SRCDIR="${SRCDIR:-src_vi}"
DOCSDIR="${DOCSDIR:-docs}"

if [[ -z "${JOBS:-}" ]]; then
    if [[ -n "${BGBS_THREADS:-}" ]]; then
        JOBS="$BGBS_THREADS"
    elif command -v nproc >/dev/null 2>&1; then
        JOBS="$(nproc)"
    else
        JOBS=4
    fi
fi

if [[ ! -f bgbspd/source.make ]]; then
    echo "bgbspd/ submodule is missing. Run: git submodule update --init"
    exit 1
fi

echo "==> Cleaning previous build products under $SRCDIR/"
make -C "$SRCDIR" pristine >/dev/null 2>&1 || true

echo "==> Building HTML, EPUB, and PDFs from $SRCDIR/ (jobs=$JOBS)"
make -j "$JOBS" -C "$SRCDIR" BGBSPD_BUILD_DIR=../bgbspd all
make -C "$SRCDIR" BGBSPD_BUILD_DIR=../bgbspd "$PACKAGE.epub"

echo "==> Staging into $DOCSDIR/"
rm -rf "$DOCSDIR"
mkdir -p "$DOCSDIR/html/split" "$DOCSDIR/html/split-wide" "$DOCSDIR/pdf" "$DOCSDIR/epub"

cp -v "$SRCDIR/$PACKAGE.html"        "$DOCSDIR/html/index.html"
cp -v "$SRCDIR/$PACKAGE-wide.html"   "$DOCSDIR/html/index-wide.html"
cp -v "$SRCDIR"/img_*.svg            "$DOCSDIR/html/" 2>/dev/null || true
cp -v "$SRCDIR"/img_*.png            "$DOCSDIR/html/" 2>/dev/null || true
cp -v "$SRCDIR"/pipe1.svg            "$DOCSDIR/html/" 2>/dev/null || true

cp -v "$SRCDIR"/split/*              "$DOCSDIR/html/split/"
cp -v "$SRCDIR"/split-wide/*         "$DOCSDIR/html/split-wide/"

(
    cd "$DOCSDIR/html"
    mkdir -p "$PACKAGE"
    cp split/* "$PACKAGE/"
    zip -rq "$PACKAGE.zip" "$PACKAGE"
    rm -rf "$PACKAGE"

    mkdir -p "$PACKAGE-wide"
    cp split-wide/* "$PACKAGE-wide/"
    zip -rq "$PACKAGE-wide.zip" "$PACKAGE-wide"
    rm -rf "$PACKAGE-wide"
)

cp -v "$SRCDIR"/"$PACKAGE"*.pdf      "$DOCSDIR/pdf/" 2>/dev/null || true
cp -v "$SRCDIR"/"$PACKAGE".epub      "$DOCSDIR/epub/" 2>/dev/null || true

if [[ -d source ]]; then
    mkdir -p "$DOCSDIR/source"
    cp -rv source/* "$DOCSDIR/source/" 2>/dev/null || true
    (cd "$DOCSDIR" && zip -rq "source/${PACKAGE}_source.zip" source -x 'source/*.zip')
fi

scripts/render_index.sh "$DOCSDIR"

echo "==> Done. Output is in $DOCSDIR/"
