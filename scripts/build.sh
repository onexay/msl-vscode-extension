#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Build the VS Code extension locally. CI runs this script to produce the VSIX
# artifact that scripts/publish.sh publishes.
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"

npm ci --no-audit --no-fund --loglevel=error
npm run compile
npm run package

VERSION=$(node -p 'require("./package.json").version')
test -s "dist/msl-$VERSION.vsix"
