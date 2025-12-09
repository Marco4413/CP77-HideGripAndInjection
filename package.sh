#!/bin/bash

set -xe

MOD_NAME='HideGripAndInjection'
MOD_VERSION="$( git describe --tags --abbrev=0 --match='v*' | sed s/^v// )"

BASE='./build'

CET_TARGET="./$BASE/bin/x64/plugins/cyber_engine_tweaks/mods/$MOD_NAME"

mkdir -p "$CET_TARGET"

CET_FILES=( 'init.lua' 'BetterUI.lua' 'Enum.lua' 'README.md' 'LICENSE.md' )
for file in "${CET_FILES[@]}"; do
    cp "$file" "$CET_TARGET"
done

mkdir -p "$CET_TARGET/data"
echo 'Thank you.' > "$CET_TARGET/data/PLEASE_VORTEX_DONT_IGNORE_THIS_FOLDER"

7z a -mx9 -r -- "$BASE/$MOD_NAME-$MOD_VERSION.zip" "./$BASE/bin"
