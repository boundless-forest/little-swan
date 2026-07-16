#!/bin/bash

set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 VERSION ARCHIVE [OUTPUT]" >&2
  exit 64
fi

version="$1"
archive="$2"
output="${3:-dist/little-swan.rb}"
template="Packaging/Homebrew/little-swan.rb.template"

[[ -f "$archive" ]] || { echo "Archive not found: $archive" >&2; exit 66; }
[[ -f "$template" ]] || { echo "Template not found: $template" >&2; exit 66; }
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || {
  echo "Version must be SemVer-compatible: $version" >&2
  exit 65
}

sha256="$(shasum -a 256 "$archive" | awk '{print $1}')"
mkdir -p "$(dirname "$output")"
sed -e "s/__VERSION__/$version/g" -e "s/__SHA256__/$sha256/g" "$template" > "$output"
echo "Rendered $output with SHA-256 $sha256"
