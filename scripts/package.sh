#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Package the extension using its SemVer version for development and release builds.
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"

BASE_VERSION=$(node -p 'require("./package.json").version')
VERSION=${MSL_VERSION:-$BASE_VERSION}
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
