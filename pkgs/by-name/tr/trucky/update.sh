#!/usr/bin/env nix-shell
#!nix-shell -i bash -p appimage-run asar curl jq common-updater-scripts

set -euo pipefail

url="https://truckyapp.com/client-download-linux"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

appimage="$tmpdir/Trucky.AppImage"
appdir="$tmpdir/app"

curl -L -sS \
  -A 'Mozilla/5.0' \
  -o "$appimage" \
  "$url"

appimage-run -x "$appdir" "$appimage" >/dev/null

asar_file="$appdir/resources/app.asar"

if [[ ! -f "$asar_file" ]]; then
  echo "error: resources/app.asar not found" >&2
  exit 1
fi

asar extract-file "$asar_file" package.json -o "$tmpdir"

upstream_version="$(jq -er '.version' "$tmpdir/package.json")"

echo "Latest Trucky version: $upstream_version"

if [[ "$UPDATE_NIX_OLD_VERSION" == "$upstream_version" ]]; then
  echo "Trucky is already up to date."
  exit 0
fi

archive_url="https://web.archive.org/save"

archived_url="$(
  curl -s -I -L \
    "$archive_url/$url" \
    -w '%{url_effective}' \
    -o /dev/null
)"

echo "Archived URL: $archived_url"

update-source-version \
  "$UPDATE_NIX_ATTR_PATH" \
  "$upstream_version" \
  "" \
  "$archived_url"
