#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Stamp the packaged extension with the source commit while keeping the
# checked-in release version as the stable base version.
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"

BASE_VERSION=$(node -p 'require("./package.json").version')
COMMIT=$(git rev-parse --short=7 HEAD)
VERSION="$BASE_VERSION+$COMMIT"
MANIFEST_BACKUP=$(mktemp)
cp package.json "$MANIFEST_BACKUP"
restore_manifest() {
  cp "$MANIFEST_BACKUP" package.json
  rm -f "$MANIFEST_BACKUP"
}
trap restore_manifest EXIT
trap 'exit 1' HUP INT TERM

node - "$VERSION" <<'NODE'
const fs = require('node:fs');
const manifest = JSON.parse(fs.readFileSync('package.json', 'utf8'));
manifest.version = process.argv[2];
fs.writeFileSync('package.json', `${JSON.stringify(manifest, null, 2)}\n`);
NODE

mkdir -p dist
vsce package --no-dependencies -o "dist/msl-$VERSION.vsix"
