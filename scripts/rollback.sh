#!/usr/bin/env bash
# Vuelve el Service a la ranura anterior, sin borrar la versión que se retira.
set -euo pipefail

NAMESPACE="${NAMESPACE:-techwave}"
PREVIOUS="$(kubectl get configmap techwave-release -n "$NAMESPACE" -o jsonpath='{.data.previous}')"
ACTIVE="$(kubectl get configmap techwave-release -n "$NAMESPACE" -o jsonpath='{.data.active}')"

if [[ -z "$PREVIOUS" ]]; then
  echo "No hay ranura anterior registrada."
  exit 1
fi

kubectl patch service techwave -n "$NAMESPACE" --type merge \
  -p "{\"spec\":{\"selector\":{\"app\":\"techwave\",\"slot\":\"$PREVIOUS\"}}}"
kubectl patch configmap techwave-release -n "$NAMESPACE" --type merge \
  -p "{\"data\":{\"active\":\"$PREVIOUS\",\"previous\":\"$ACTIVE\"}}"

echo "Rollback hecho: el tráfico vuelve a $PREVIOUS."
