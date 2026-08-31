#!/usr/bin/env bash

set -u

script_name="$(basename "$0")"

print_help() {
  cat <<EOF
Usage: $script_name <encode|decode> <location> [--pattern <substring> ...]

Encrypt/decrypt files with sops from a file or directory (recursive).

Arguments:
  encode|decode              Action to execute with sops
  location                   File or directory to process

Options:
  -p, --pattern <substring>  Substring to match in file path (repeatable)
                             Default patterns:
                               - .sops.yaml
                               - .sops.yml
  -h, --help                 Show this help message
EOF
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

contains_pattern() {
  local file_path="$1"
  local pattern

  for pattern in "${patterns[@]}"; do
    if [[ "$file_path" == *"$pattern"* ]]; then
      return 0
    fi
  done

  return 1
}

if [[ $# -lt 2 ]]; then
  print_help
  exit 1
fi

action="$1"
location="$2"
shift 2

patterns=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--pattern)
      [[ $# -ge 2 ]] || fail "Missing value after $1"
      patterns+=("$2")
      shift 2
      ;;
    -h|--help)
      print_help
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

if [[ "$action" != "encode" && "$action" != "decode" ]]; then
  fail "Action must be 'encode' or 'decode'"
fi

if [[ ! -e "$location" ]]; then
  fail "Location does not exist: $location"
fi

if ! command -v sops >/dev/null 2>&1; then
  fail "sops is not installed or not in PATH"
fi

if [[ ${#patterns[@]} -eq 0 ]]; then
  patterns=(".sops.yaml" ".sops.yml")
fi

declare -a candidates=()

if [[ -f "$location" ]]; then
  candidates=("$location")
elif [[ -d "$location" ]]; then
  if command -v rg >/dev/null 2>&1; then
    while IFS= read -r -d '' file_path; do
      candidates+=("$file_path")
    done < <(rg --files -0 "$location")
  elif command -v grep >/dev/null 2>&1; then
    while IFS= read -r -d '' file_path; do
      candidates+=("$file_path")
    done < <(grep -RIlZ '' "$location")
  else
    fail "Neither rg nor grep is available to discover files"
  fi
else
  fail "Location is neither a file nor a directory: $location"
fi

declare -A seen=()
declare -a files_to_process=()

for file_path in "${candidates[@]}"; do
  if [[ -f "$file_path" ]] && contains_pattern "$file_path"; then
    if [[ -z "${seen[$file_path]+x}" ]]; then
      files_to_process+=("$file_path")
      seen["$file_path"]=1
    fi
  fi
done

printf 'Action: %s\n' "$action"
printf 'Location: %s\n' "$location"
printf 'Patterns: %s\n' "${patterns[*]}"
printf 'Matched files: %d\n\n' "${#files_to_process[@]}"

if [[ ${#files_to_process[@]} -eq 0 ]]; then
  printf 'No files matched the provided pattern(s).\n'
  exit 0
fi

ok_count=0
fail_count=0

for file_path in "${files_to_process[@]}"; do
  if [[ "$action" == "encode" ]]; then
    if sops --encrypt --in-place "$file_path"; then
      printf '[OK] encode %s\n' "$file_path"
      ((ok_count++))
    else
      printf '[KO] encode %s\n' "$file_path" >&2
      ((fail_count++))
    fi
  else
    if sops --decrypt --in-place "$file_path"; then
      printf '[OK] decode %s\n' "$file_path"
      ((ok_count++))
    else
      printf '[KO] decode %s\n' "$file_path" >&2
      ((fail_count++))
    fi
  fi
done

printf '\nDone. Success: %d | Failed: %d\n' "$ok_count" "$fail_count"

if [[ $fail_count -gt 0 ]]; then
  exit 1
fi
