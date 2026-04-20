#!/usr/bin/env bash
# Create and (optionally) push a release tag.
#
# Usage:
#   ./scripts/release.sh                 # inspect, confirm, tag locally
#   ./scripts/release.sh --push          # also push the tag
#   ./scripts/release.sh --revision 3    # force specific vi.N
#   ./scripts/release.sh --tag v1.5.5-vi.1  # force full tag

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PUSH=0; FORCE_TAG=""; FORCE_REV=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --push) PUSH=1; shift ;;
        --tag) FORCE_TAG="$2"; shift 2 ;;
        --revision) FORCE_REV="$2"; shift 2 ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
done

if [[ -n "$FORCE_TAG" ]]; then
    TAG="$FORCE_TAG"
else
    UPSTREAM_VERSION="$(sed -nE 's/VERSION_DATE="(v[0-9.]+).*/\1/p' src/Makefile)"
    [[ -z "$UPSTREAM_VERSION" ]] && { echo "Could not parse version from src/Makefile" >&2; exit 1; }
    if [[ -n "$FORCE_REV" ]]; then
        N="$FORCE_REV"
    else
        LAST="$(git tag --list "${UPSTREAM_VERSION}-vi.*" | sed -E 's/.*-vi\.([0-9]+)/\1/' | sort -n | tail -1 || true)"
        if [[ -z "$LAST" ]]; then N=1; else N=$((LAST + 1)); fi
    fi
    TAG="${UPSTREAM_VERSION}-vi.${N}"
fi

UPSTREAM_COMMIT="$(grep -oE '\*\*Commit:\*\* `[a-f0-9]+`' UPSTREAM.md | head -1 | sed -E 's/.*`([a-f0-9]+)`.*/\1/')"
[[ -z "$UPSTREAM_COMMIT" ]] && { echo "Could not read upstream commit from UPSTREAM.md" >&2; exit 1; }

git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && { echo "Tag $TAG already exists." >&2; exit 1; }
[[ -n "$(git status --porcelain)" ]] && { echo "Working tree has uncommitted changes." >&2; exit 1; }

echo
echo "  Tag:              $TAG"
echo "  HEAD:             $(git rev-parse HEAD)"
echo "  Upstream commit:  $UPSTREAM_COMMIT"
echo "  Push after tag:   $([[ $PUSH -eq 1 ]] && echo yes || echo no)"
echo

read -r -p "Proceed? [y/N] " REPLY
[[ ! "$REPLY" =~ ^[Yy]$ ]] && { echo "Aborted."; exit 1; }

git tag -a "$TAG" -m "Release $TAG

Vietnamese translation based on upstream beejjorgensen/bgipc@$UPSTREAM_COMMIT."
echo "Created tag $TAG."

if [[ $PUSH -eq 1 ]]; then
    git push origin "$TAG"
    echo "Pushed $TAG. Release workflow should start shortly."
else
    echo "Tag is local only. Push with: git push origin $TAG"
fi
