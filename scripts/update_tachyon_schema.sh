#!/usr/bin/env bash

# Downloads the JSON schemas from the Tachyon repository (https://github.com/beyond-all-reason/tachyon)
# and puts them in `priv/tachyon/v<major_version>/schema`, replacing existing files
#
# Usage:
# ./scripts/update_tachyon_schema.sh <major_version> [ref] [schema...]
# `major_version` is the Tachyon protocol version the schemas are for
# `ref` is the branch, tag or commit of the Tachyon repository, defaults to `master`
# `schema` are the schemas to update, e.g. autohost or clan, defaults to all of them

set -euo pipefail

# run from the repository root
cd "$(dirname "$0")/.."

usage="usage: ./scripts/update_tachyon_schema.sh <major_version> [ref] [schema...]"
version="${1:-}"
ref="${2:-master}"
schemas=("${@:3}")

if ! [[ "$version" =~ ^[0-9]+$ ]]; then
  echo "Invalid major version: $version" >&2
  echo "$usage" >&2
  exit 1
fi

for schema in "${schemas[@]}"; do
  if ! [[ "$schema" =~ ^[A-Za-z0-9_-]+$ ]]; then
    echo "Invalid schema: $schema" >&2
    echo "$usage" >&2
    exit 1
  fi
done

dest="priv/tachyon/v$version/schema"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Downloading tachyon $ref"
if ! curl -fsSL -o "$tmp/tachyon.tar.gz" "https://codeload.github.com/beyond-all-reason/tachyon/tar.gz/$ref"; then
  echo "Could not download tachyon $ref" >&2
  exit 1
fi

# only extract the schemas, dropping the tachyon-<ref>/schema/ prefix
# compiled.json bundles all the other schemas, teiserver doesn't use it
src="$tmp/schema"
mkdir "$src"
if ! tar -xzf "$tmp/tachyon.tar.gz" -C "$src" --strip-components=2 \
  --wildcards --no-wildcards-match-slash '*/schema/*' --exclude '*/schema/compiled.json'; then
  echo "No schemas found in tachyon $ref" >&2
  exit 1
fi

if [ ${#schemas[@]} -eq 0 ]; then
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  cp -r "$src" "$dest"
  echo "Wrote $(find "$dest" -name '*.json' | wc -l) schemas from tachyon $ref into $dest"
else
  # check all schemas first so nothing is replaced if one is missing
  for schema in "${schemas[@]}"; do
    if [ ! -d "$src/$schema" ]; then
      echo "No $schema schemas in tachyon $ref" >&2
      exit 1
    fi
  done

  mkdir -p "$dest"
  for schema in "${schemas[@]}"; do
    rm -rf "${dest:?}/$schema"
    cp -r "$src/$schema" "$dest/$schema"
    echo "Wrote $(find "$dest/$schema" -name '*.json' | wc -l) $schema schemas from tachyon $ref into $dest/$schema"
  done
fi

echo "Done"
