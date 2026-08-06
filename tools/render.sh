#!/usr/bin/env bash
# Renders an app the way ArgoCD does: env values, then cluster/namespace values.
# DEVOPS_INFRA_CHART=<path to charts/devops_infra> renders against an unreleased local chart instead of the
# published one, for apps whose version constraint admits it.
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "usage: $0 <app> <cluster> [namespace]" >&2
  exit 2
fi
app=$1 cluster=$2 only_ns=${3:-}
root=$(cd "$(dirname "$0")/.." && pwd)
app_dir=$root/apps/$app

case $cluster in
  dev-*) env=development envType=dev ;;
  prod-*) env=production envType=prod ;;
  *) echo "unknown cluster prefix: $cluster" >&2; exit 2 ;;
esac
region=$(echo "$cluster" | cut -d- -f3)
cluster_dir=$app_dir/$env/$cluster

[ -d "$app_dir" ] || { echo "no such app: $app" >&2; exit 1; }
[ -d "$cluster_dir" ] || { echo "$app is not deployed to $cluster" >&2; exit 1; }

chart_dir=$app_dir
if [ -n "${DEVOPS_INFRA_CHART:-}" ] && grep -q 'name: devops_infra' "$app_dir/Chart.yaml"; then
  local_chart=$(cd "$DEVOPS_INFRA_CHART" && pwd)
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  cp -R "$app_dir/." "$tmp/"
  rm -rf "$tmp/charts" "$tmp/Chart.lock"
  sed -i.bak "s#repository: .*#repository: file://$local_chart#" "$tmp/Chart.yaml"
  if helm dependency update "$tmp" >/dev/null 2>&1; then
    chart_dir=$tmp
  else
    echo "note: $app's devops_infra constraint does not admit the local chart; using the published one" >&2
  fi
fi
[ "$chart_dir" = "$app_dir" ] && helm dependency update "$app_dir" >/dev/null

for ns_dir in "$cluster_dir"/*/; do
  ns=$(basename "$ns_dir")
  [ -z "$only_ns" ] || [ "$ns" = "$only_ns" ] || continue
  files=()
  [ "$env" = development ] && files+=(-f "$app_dir/development/values.yaml")
  files+=(-f "$ns_dir/values.yaml")
  echo "# ===== $cluster/$ns"
  helm template "$app" "$chart_dir" --namespace "$ns" "${files[@]}" \
    --set global.envType="$envType" --set global.region="$region" --set global.clusterName="$cluster"
done
