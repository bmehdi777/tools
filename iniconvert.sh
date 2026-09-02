#!/usr/bin/env bash

set -euo pipefail

script_name="$(basename "$0")"

print_help() {
  cat <<EOF
Usage: $script_name [-i INPUT_FILE] [-o OUTPUT_FILE] [-f FROM] [-t TO]

Convert between INI, JSON, and YAML.

Defaults:
  - Reads from stdin when -i is not provided
  - FROM format defaults to ini
  - TO format defaults to json

Options:
  -i, --input <file>      Input file (otherwise stdin)
  -o, --output <file>     Output file (otherwise stdout)
  -f, --from <format>     Input format: ini|json (default: ini)
  -t, --to <format>       Output format: json|yaml|ini (default: json)
  -h, --help              Show this help message

Examples:
  # Default: INI to JSON from stdin
  cat config.ini | $script_name

  # INI file to YAML
  $script_name -i config.ini -t yaml

  # .env-style key/value file to JSON
  $script_name -i .env.dev

  # JSON file to INI
  $script_name -i config.json -f json -t ini
EOF
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

input_file=""
output_file=""
from_format="ini"
to_format="json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--input)
      [[ $# -ge 2 ]] || fail "Missing value after $1"
      input_file="$2"
      shift 2
      ;;
    -o|--output)
      [[ $# -ge 2 ]] || fail "Missing value after $1"
      output_file="$2"
      shift 2
      ;;
    -f|--from)
      [[ $# -ge 2 ]] || fail "Missing value after $1"
      from_format="$2"
      shift 2
      ;;
    -t|--to)
      [[ $# -ge 2 ]] || fail "Missing value after $1"
      to_format="$2"
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

case "$from_format" in
  ini|json) ;;
  *) fail "Unsupported input format: $from_format (allowed: ini|json)" ;;
esac

case "$to_format" in
  json|yaml|ini) ;;
  *) fail "Unsupported output format: $to_format (allowed: json|yaml|ini)" ;;
esac

if [[ -n "$input_file" && ! -f "$input_file" ]]; then
  fail "Input file does not exist: $input_file"
fi

require_cmd python3
if [[ "$to_format" == "yaml" ]]; then
  require_cmd yq
fi

if [[ -n "$input_file" ]]; then
  input_content="$(<"$input_file")"
else
  input_content="$(cat)"
fi

if [[ -z "$input_content" ]]; then
  fail "Input is empty"
fi

convert_ini_to_json() {
  python3 -c '
import configparser
import io
import json
import sys

data = sys.stdin.read()
parser = configparser.ConfigParser()
parser.optionxform = str

try:
    parser.read_file(io.StringIO(data))
except configparser.MissingSectionHeaderError:
    result = {}
    for idx, raw_line in enumerate(data.splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith(";"):
            continue
        if "=" not in line:
            print(f"Invalid key/value input at line {idx}: expected KEY=VALUE", file=sys.stderr)
            sys.exit(1)
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key:
            print(f"Invalid key/value input at line {idx}: empty key", file=sys.stderr)
            sys.exit(1)
        result[key] = value
    print(json.dumps(result, indent=2, ensure_ascii=False))
    sys.exit(0)
except Exception as exc:
    print(f"Invalid INI input: {exc}", file=sys.stderr)
    sys.exit(1)

result = {section: dict(parser.items(section)) for section in parser.sections()}
print(json.dumps(result, indent=2, ensure_ascii=False))
'
}

normalize_json() {
  python3 -c '
import json
import sys

try:
    obj = json.load(sys.stdin)
except Exception as exc:
    print(f"Invalid JSON input: {exc}", file=sys.stderr)
    sys.exit(1)

print(json.dumps(obj, indent=2, ensure_ascii=False))
'
}

convert_json_to_ini_strict() {
  python3 -c '
import configparser
import json
import sys

def scalar_to_ini(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    if isinstance(value, (int, float, str)):
        return str(value)
    raise TypeError("non-scalar value")

try:
    obj = json.load(sys.stdin)
except Exception as exc:
    print(f"Invalid JSON input: {exc}", file=sys.stderr)
    sys.exit(1)

if not isinstance(obj, dict):
    print("Invalid JSON shape for INI conversion: expected a top-level object", file=sys.stderr)
    sys.exit(1)

def is_scalar(value):
    return value is None or isinstance(value, (bool, int, float, str))

is_flat = all(is_scalar(value) for value in obj.values())
is_sectioned = all(isinstance(value, dict) for value in obj.values())

if is_flat:
    for key, value in obj.items():
        if not isinstance(key, str):
            print("Invalid JSON shape for INI conversion: keys must be strings", file=sys.stderr)
            sys.exit(1)
        print(f"{key}={scalar_to_ini(value)}")
    sys.exit(0)

if not is_sectioned:
    print("Invalid JSON shape for INI conversion: top-level values must be either all scalars or all objects", file=sys.stderr)
    sys.exit(1)

parser = configparser.ConfigParser()
parser.optionxform = str

for section, values in obj.items():
    if not isinstance(section, str):
        print("Invalid JSON shape for INI conversion: section keys must be strings", file=sys.stderr)
        sys.exit(1)
    if not isinstance(values, dict):
        print("Invalid JSON shape for INI conversion: each section must map to an object", file=sys.stderr)
        sys.exit(1)

    parser[section] = {}
    for key, value in values.items():
        if not isinstance(key, str):
            print("Invalid JSON shape for INI conversion: keys must be strings", file=sys.stderr)
            sys.exit(1)
        if isinstance(value, (dict, list)):
            print("Invalid JSON shape for INI conversion: nested objects/arrays are not allowed", file=sys.stderr)
            sys.exit(1)
        try:
            parser[section][key] = scalar_to_ini(value)
        except TypeError:
            print("Invalid JSON shape for INI conversion: unsupported value type", file=sys.stderr)
            sys.exit(1)

parser.write(sys.stdout)
'
}

json_payload=""

if [[ "$from_format" == "ini" ]]; then
  json_payload="$(printf '%s' "$input_content" | convert_ini_to_json)"
else
  json_payload="$(printf '%s' "$input_content" | normalize_json)"
fi

final_output=""

case "$to_format" in
  json)
    final_output="$json_payload"
    ;;
  yaml)
    final_output="$(printf '%s' "$json_payload" | yq -P)"
    ;;
  ini)
    if [[ "$from_format" != "json" ]]; then
      fail "INI output requires JSON input. Use -f json -t ini."
    fi
    final_output="$(printf '%s' "$json_payload" | convert_json_to_ini_strict)"
    ;;
esac

if [[ -n "$output_file" ]]; then
  printf '%s\n' "$final_output" > "$output_file"
else
  printf '%s\n' "$final_output"
fi
