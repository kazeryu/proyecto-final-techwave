#!/usr/bin/env bash
# Crea el clúster local, carga la imagen y aplica los manifiestos de la aplicación.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

docker build -t ghcr.io/kazeryu/proyecto-final-techwave:1.0.0 .
if ! kind get clusters | grep -qx techwave; then
  kind create cluster --name techwave --config k8s/kind-config.yaml
fi
kind load docker-image ghcr.io/kazeryu/proyecto-final-techwave:1.0.0 --name techwave

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/deployment-blue.yaml
kubectl apply -f k8s/deployment-green.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml
kubectl rollout status deployment/techwave-blue -n techwave --timeout=120s
kubectl rollout status deployment/techwave-green -n techwave --timeout=120s
kubectl get deploy,svc,ingress -n techwave
echo "Aplicación en http://127.0.0.1:30080"
