#!/bin/bash
set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

# Fails if Cargo.lock resolves the crates below to public sources (a build without the fix).

# Each entry is "<crate name glob>|<required source prefix>".
REQUIRED_SOURCES=(
  "cosmwasm-*|git+https://github.com/CosmWasm/priv_cosmwasm.git"
)

lockfile="${1:-libwasmvm/Cargo.lock}"

if [[ ! -f "$lockfile" ]]; then
  echo "error: lockfile not found: $lockfile" >&2
  exit 1
fi

# One "<name>\t<source>" line per [[package]]; path deps have no source.
packages="$(
  awk '
    /^\[\[package\]\]/ { name = ""; source = ""; next }
    /^name = /   { gsub(/"/, "", $3); name = $3; next }
    /^source = / { gsub(/"/, "", $3); source = $3; next }
    /^[[:space:]]*$/ {
      if (name != "") print name "\t" source
      name = ""; source = ""
    }
    END { if (name != "") print name "\t" source }
  ' "$lockfile"
)"

failures=0
matched=0

for entry in "${REQUIRED_SOURCES[@]}"; do
  pattern="${entry%%|*}"
  required="${entry#*|}"

  while IFS=$'\t' read -r name source; do
    # shellcheck disable=SC2053 # the right-hand side is deliberately a glob
    [[ $name == $pattern ]] || continue
    matched=$((matched + 1))

    if [[ $source != "$required"* ]]; then
      echo "FAIL $name is resolved from '${source:-<local path>}'" >&2
      echo "     but an embargoed build requires '$required'" >&2
      failures=$((failures + 1))
    else
      echo "ok   $name <- $source"
    fi
  done <<<"$packages"
done

if [[ $matched -eq 0 ]]; then
  echo "error: no package in $lockfile matched any pattern in REQUIRED_SOURCES." >&2
  echo "       The guard is not actually checking anything - fix the patterns." >&2
  exit 1
fi

if [[ $failures -gt 0 ]]; then
  echo >&2
  echo "$failures package(s) resolve to public sources. This build would NOT" >&2
  echo "contain the embargoed fix. Check [patch.crates-io] in libwasmvm/Cargo.toml." >&2
  exit 1
fi

echo
echo "All $matched checked package(s) resolve to the expected private sources."
