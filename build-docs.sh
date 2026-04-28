#!/usr/bin/env bash
# Build docs.json for the elm-tui package.
#
# Runs `elm make --docs=docs.json` against the package `elm.json`. The
# elm-pages dependency is resolved through the usual Elm package cache.
# For local development against an in-progress elm-pages checkout, symlink
# ~/.elm/0.19.1/packages/dillonkearns/elm-pages/<version> at that checkout
# so changes are picked up without publishing — and clear that checkout's
# artifacts.dat / artifacts.x.dat if you hit ghost "module not found"
# errors for symbols that obviously exist.

set -euo pipefail

cd "$(dirname "$0")"

# Wipe stale local caches.
rm -rf elm-stuff

# Build docs against the package elm.json.
npx elm make --docs=docs.json

echo ""
echo "Wrote docs.json"
