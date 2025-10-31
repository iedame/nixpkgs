#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl gnused nurl jq

set -eu

ROOT="$(dirname "$(readlink -f "$0")")"
NIX_DRV="$ROOT/package.nix"
if [ ! -f "$NIX_DRV" ]; then
  echo "ERROR: cannot find package.nix in $ROOT"
  exit 1
fi

fetch_darwin() {
  VER="$1"
  URL="https://github.com/aonez/Keka/releases/download/v${VER}/Keka-${VER}.zip"
  nurl --hash --expr "(import <nixpkgs> { }).fetchzip { url = \"$URL\"; }"
}

replace_sha() {
  sed -i "s|hash = \"sha256-.\{44\}\";|hash = \"$1\";|" "$NIX_DRV"
}

LATEST_VERSION="$(curl ${GITHUB_TOKEN:+" -u \":$GITHUB_TOKEN\""} -s "https://api.github.com/repos/aonez/Keka/releases" | jq -r  'map(select(.prerelease == false)) | .[0].tag_name | sub("^v"; "")')"

if [ -z "$LATEST_VERSION" ]; then
    echo "ERROR: Failed to scrape the latest version."
    exit 1
fi

NEW_SHA256=$(fetch_darwin "$LATEST_VERSION")

sed -i "s/version = \".*\"/version = \"$LATEST_VERSION\"/" "$NIX_DRV"

replace_sha "$NEW_SHA256"
