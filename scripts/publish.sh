#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Publish the MSL VS Code extension CI built (.github/workflows/vscode.yml,
# artifact vscode-<full-version>) as GitHub release vscode-<full-version>, where
# <full-version> is the base package.json version plus the source commit hash.
# The artifact must come from a commit whose tree is
# identical to HEAD's. msl then pins it: scripts/pin.sh vscode <tag> in msl.
#   ./scripts/publish.sh
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
cd "$HERE"
REPO=${MSL_VSCODE_REPO:-onexay/msl-vscode-extension}
VERSION=$(sed -n 's/^  "version": "\(.*\)",$/\1/p' package.json)
SHORT=$(git rev-parse --short=7 HEAD)
FULL_VERSION=$VERSION+$SHORT
TAG=vscode-$FULL_VERSION
FILE=msl-$VERSION+$SHORT.vsix
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "$TAG is already published: bump \"version\" in package.json" >&2; exit 1
fi
[ -z "$(git status --porcelain)" ] || { echo "commit your changes first" >&2; exit 1; }
git fetch -q origin && [ "$(git rev-parse HEAD)" = "$(git rev-parse "@{u}")" ] || { echo "push HEAD first" >&2; exit 1; }

# The artifact CI built from HEAD itself: a pull request that bumps the
# version builds artifacts of the same name from its own commits.
HEAD_SHA=$(git rev-parse HEAD)
RUN=$(gh api "repos/$REPO/actions/artifacts?name=$TAG&per_page=50" --jq "[.artifacts[] | select((.expired | not) and .workflow_run.head_sha == \"$HEAD_SHA\")][0].workflow_run.id // empty")
[ -n "$RUN" ] || { echo "CI hasn't built $TAG from HEAD yet: push the change and wait for the VS Code extension workflow" >&2; exit 1; }
rm -rf dist/ci && gh run download "$RUN" --repo "$REPO" --name "$TAG" --dir dist/ci
BUILT=$(sed -n 's/^commit //p' dist/ci/build-info.txt)
[ "$(git rev-parse "$BUILT^{tree}")" = "$(git rev-parse "HEAD^{tree}")" ] \
  || { echo "CI run $RUN built $TAG from $BUILT, whose tree differs from HEAD's" >&2; exit 1; }
mkdir -p dist && cp "dist/ci/$FILE" "dist/$FILE"
(cd dist && shasum -a 256 "$FILE" > release.sha256)
gh release create "$TAG" "dist/$FILE" dist/release.sha256 --repo "$REPO" \
  --target "$(git rev-parse HEAD)" \
  --title "MSL VS Code extension $FULL_VERSION" \
  --notes "The MSL extension for VS Code and similar IDEs (VS Code Insiders, VSCodium, Cursor), built by CI run $RUN at $(git rev-parse --short "$BUILT"). msl releases bundle it, and \`msl --manage-ide\` installs it. It uses VS Code's proposed \`resolvers\` API, so it isn't on the Marketplace.

\`$FILE\` SHA-256: \`$(cut -d' ' -f1 dist/release.sha256)\`"
echo "published $TAG; pin it in msl: scripts/pin.sh vscode $TAG"
