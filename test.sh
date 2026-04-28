#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"

cleanup() {
    if [ -n "${temp_dir:-}" ] && [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
    fi
}

trap cleanup EXIT

cd "$repo_root"

temp_dir="$repo_root/$(mktemp -d .tmp-elm-tui-tests.XXXXXX)"

cp elm-application.json "$temp_dir/elm.json"
ln -s "$repo_root/src" "$temp_dir/src"
ln -s "$repo_root/examples" "$temp_dir/examples"
ln -s "$repo_root/tests" "$temp_dir/tests"

cd "$temp_dir"

if [ "$#" -eq 0 ]; then
    set -- tests/*.elm
fi

npx elm-test "$@"
