#!/usr/bin/env bash

set -euo pipefail

script_name="$(basename "$0")"

print_help() {
  cat <<EOF
Usage: $script_name <service> [port]

Print the fully qualified Kubernetes DNS name for a Service in the current
kubectl context. The namespace is read from the current context, falling back
to default. The cluster domain is detected from the CoreDNS Corefile.

Arguments:
  service       Kubernetes Service name
  port          Kubernetes Service port (1-65535). Detected when omitted if
                the Service exposes exactly one port.

Example:
  $script_name api
  $script_name api 8080
EOF
}

fail() {
  printf 'Error: %s\n' "$1" >&2
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_help
  exit 0
fi

[[ $# -ge 1 && $# -le 2 ]] || {
  print_help >&2
  exit 1
}

command -v kubectl >/dev/null 2>&1 || fail "kubectl is not installed or not in PATH"

service="$1"
port="${2:-}"
namespace="$(kubectl config view --minify --output 'jsonpath={..namespace}')"
namespace="${namespace:-default}"

for value in "$service" "$namespace"; do
  [[ "$value" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || fail "Invalid Kubernetes DNS label: $value"
done

if [[ -n "$port" ]]; then
  [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)) || fail "Invalid port: $port (expected 1-65535)"
else
  service_ports="$(kubectl -n "$namespace" get service "$service" -o go-template='{{range .spec.ports}}{{.port}}{{"\n"}}{{end}}' 2>/dev/null)" \
    || fail "Unable to read Service $service in namespace $namespace"

  mapfile -t ports <<<"$service_ports"

  if [[ ${#ports[@]} -eq 0 || -z "${ports[0]}" ]]; then
    fail "Service $service in namespace $namespace does not expose a port"
  fi

  if [[ ${#ports[@]} -gt 1 ]]; then
    fail "Service $service in namespace $namespace exposes multiple ports (${ports[*]}). Specify one explicitly."
  fi

  port="${ports[0]}"
fi

cluster_domain=""

for config_map in coredns kube-dns; do
  if corefile="$(kubectl -n kube-system get configmap "$config_map" -o go-template='{{index .data "Corefile"}}' 2>/dev/null)"; then
    cluster_domain="$(awk '
      $1 == "kubernetes" {
        for (field = 2; field <= NF; field++) {
          if ($field !~ /^(in-addr\.arpa|ip6\.arpa|\{$)/) {
            print $field
            exit
          }
        }
      }
    ' <<<"$corefile")"

    [[ -n "$cluster_domain" ]] && break
  fi
done

[[ -n "$cluster_domain" ]] || fail "Unable to detect the cluster DNS domain from the CoreDNS Corefile in kube-system"

printf '%s.%s.svc.%s:%s\n' "$service" "$namespace" "$cluster_domain" "$port"
