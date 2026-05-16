#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'usage: %s <binary> <rootfs>\n' "$0" >&2
  exit 1
fi

BINARY="$1"
ROOTFS="$2"

ldd_output="$(ldd "$BINARY" 2>/dev/null || true)"

if [[ -z "$ldd_output" ]]; then
  exit 0
fi

printf '%s\n' "$ldd_output" | while IFS= read -r line; do
  line="${line#"${line%%[![:space:]]*}"}"

  case "$line" in
    *"=>"*"/"*)
      lib_path="$(printf '%s\n' "$line" | awk '{print $3}')"
      ;;
    /*)
      lib_path="$(printf '%s\n' "$line" | awk '{print $1}')"
      ;;
    *)
      lib_path=""
      ;;
  esac

  if [[ -n "$lib_path" && -f "$lib_path" ]]; then
    target_dir="$ROOTFS$(dirname "$lib_path")"
    mkdir -p "$target_dir"
    cp -L "$lib_path" "$target_dir/"
  fi
done
