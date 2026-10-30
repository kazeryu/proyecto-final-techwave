#!/usr/bin/env bash
# Publica una versión en la ranura inactiva y solo conmuta el Service si queda Ready.
# Si el rollout o /health fallan, deshace ese Deployment y deja el tráfico donde estaba.
set -euo pipefail

NAMESPACE="${NAMESPACE:-techwave}"
VERSION=""
FAIL="false"
IMAGE="${IMAGE:-ghcr.io/kazeryu/proyecto-final-techwave:1.0.0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --image) IMAGE="$2"; shift 2 ;;
    --fail) FAIL="true"; shift ;;
    *) echo "Uso: $0 --version 1.1.0 [--image techwave:1.0.0] [--fail]"; exit 2 ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Falta --version"
  exit 2
fi

ACTIVE="$(kubectl get configmap techwave-release -n "$NAMESPACE" -o jsonpath='{.data.active}')"
if [[ "$ACTIVE" == "blue" ]]; then
  TARGET="green"
else
  TARGET="blue"
fi

echo "Activa: $ACTIVE. Desplegando $VERSION en $TARGET (FAIL_HEALTH=$FAIL, imagen=$IMAGE)"

kubectl set image "deployment/techwave-$TARGET" -n "$NAMESPACE" "app=$IMAGE"
kubectl set env "deployment/techwave-$TARGET" -n "$NAMESPACE" \
  "APP_VERSION=$VERSION" \
  "APP_COLOR=$TARGET" \
  "FAIL_HEALTH=$FAIL"

if ! kubectl rollout status "deployment/techwave-$TARGET" -n "$NAMESPACE" --timeout=90s; then
  echo "ROLLBACK: el Deployment $TARGET no ha quedado Ready. Se deshace y el Service sigue en $ACTIVE."
  kubectl rollout undo "deployment/techwave-$TARGET" -n "$NAMESPACE"
  kubectl rollout status "deployment/techwave-$TARGET" -n "$NAMESPACE" --timeout=90s
  exit 1
fi

POD="$(kubectl get pod -n "$NAMESPACE" -l "app=techwave,slot=$TARGET" -o jsonpath='{.items[0].metadata.name}')"
if ! kubectl exec -n "$NAMESPACE" "$POD" -- python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health')"; then
  echo "ROLLBACK: /health ha fallado en $TARGET. Se deshace y el Service sigue en $ACTIVE."
  kubectl rollout undo "deployment/techwave-$TARGET" -n "$NAMESPACE"
  kubectl rollout status "deployment/techwave-$TARGET" -n "$NAMESPACE" --timeout=90s
  exit 1
fi

kubectl patch service techwave -n "$NAMESPACE" --type merge \
  -p "{\"spec\":{\"selector\":{\"app\":\"techwave\",\"slot\":\"$TARGET\"}}}"
kubectl patch configmap techwave-release -n "$NAMESPACE" --type merge \
  -p "{\"data\":{\"active\":\"$TARGET\",\"previous\":\"$ACTIVE\"}}"

echo "Tráfico conmutado a $TARGET ($VERSION)."
