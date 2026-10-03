#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Build the VS Code extension locally or in CI.
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"

npm ci --no-audit --no-fund --loglevel=error
npm run compile
npm run package

BASE_VERSION=$(node -p 'require("./package.json").version')
VERSION=${MSL_VERSION:-$BASE_VERSION}
test -s "dist/msl-$VERSION.vsix"
