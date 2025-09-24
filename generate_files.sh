#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <num_folders> <num_files> [folder_prefix] [file_prefix]

Creates <num_folders> directories and <num_files> empty files in the current directory,
naming them with the given prefixes plus a unique random suffix.

Examples:
  $(basename "$0") 3 5
  $(basename "$0") 2 4 proj_ doc_
EOF
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then usage; exit 0; fi
if [[ $# -lt 2 ]]; then
  echo "Error: need at least <num_folders> and <num_files>." >&2
  usage
  exit 1
fi

num_folders="$1"
num_files="$2"
folder_prefix="${3:-folder_}"
file_prefix="${4:-file_}"

# Validate numbers
[[ "$num_folders" =~ ^[0-9]+$ ]] || { echo "num_folders must be a non-negative integer." >&2; exit 1; }
[[ "$num_files"   =~ ^[0-9]+$ ]] || { echo "num_files must be a non-negative integer." >&2; exit 1; }

# Generate a reasonably unique suffix (prefers openssl, falls back to time+pid+RANDOM)
rand_suffix() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 5 | tr -d '\n'
  else
    printf '%s' "$(date +%s)$$$RANDOM"
  fi
}

# Create folders
for ((i=1; i<=num_folders; i++)); do
  while :; do
    name="${folder_prefix}$(rand_suffix)"
    if [[ ! -e "$name" ]]; then
      mkdir -p -- "$name"
      break
    fi
  done
done

# Create files
for ((i=1; i<=num_files; i++)); do
  while :; do
    name="${file_prefix}$(rand_suffix).txt"
    if [[ ! -e "$name" ]]; then
      : > "$name"   # create empty file
      break
    fi
  done
done

echo "Process completed, generated ${num_files} files and ${num_folders} folders"