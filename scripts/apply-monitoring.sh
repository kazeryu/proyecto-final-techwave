#!/usr/bin/env bash
# Crea los ConfigMap de observabilidad y aplica el stack en Kubernetes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
kubectl apply -f "$ROOT/k8s/monitoring/stack.yaml" --dry-run=client >/dev/null
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

kubectl create configmap otel-collector -n monitoring \
  --from-file=config.yaml="$ROOT/observability/otel-collector-k8s.yaml" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create configmap prometheus-config -n monitoring \
  --from-file=prometheus.yml="$ROOT/observability/prometheus-k8s.yml" \
  --from-file=alerts.yml="$ROOT/observability/alerts.yml" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create configmap loki-config -n monitoring \
  --from-file=loki.yml="$ROOT/observability/loki.yml" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f "$ROOT/k8s/monitoring/stack.yaml"
kubectl rollout restart deployment/prometheus deployment/loki deployment/otel-collector -n monitoring
echo "Stack de monitorización aplicado en el namespace monitoring."
