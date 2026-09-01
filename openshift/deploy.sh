#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="${OPENSHIFT_PROJECT:-crt-20230367-dev}"

echo "=== EventHub OpenShift Deployment ==="
echo "Project: ${PROJECT}"
echo ""

# Step 1: Switch to project
echo "[1/6] Switching to project..."
oc project "${PROJECT}"

# Step 2: Create secrets from local keys
echo "[2/6] Creating secrets..."
if [[ -f "${ROOT}/keys/public.pem" && -f "${ROOT}/keys/private.pem" ]]; then
  oc create secret generic jwt-keys \
    --namespace "${PROJECT}" \
    --from-file=public.pem="${ROOT}/keys/public.pem" \
    --from-file=private.pem="${ROOT}/keys/private.pem" \
    --dry-run=client -o yaml | oc apply -f -
else
  echo "  WARNING: keys not found. Skipping jwt-keys secret creation."
  echo "  Create manually: oc create secret generic jwt-keys --namespace ${PROJECT} --from-file=public.pem=keys/public.pem --from-file=private.pem=keys/private.pem"
fi

oc create secret generic pg-credentials \
  --namespace "${PROJECT}" \
  --from-literal=password=eventhub \
  --dry-run=client -o yaml | oc apply -f -

oc create secret generic mysql-credentials \
  --namespace "${PROJECT}" \
  --from-literal=root-password=rootpassword \
  --dry-run=client -o yaml | oc apply -f -

# Step 3: Apply all OpenShift manifests (ImageStreams, BuildConfigs, Deployments, Services, Routes)
echo "[3/6] Applying manifests..."
oc apply -k "${ROOT}/openshift/"

# Step 4: Trigger builds for all services
echo "[4/6] Triggering builds..."
for svc in eh-auth eh-catalog eh-booking eh-insight eh-analytics eh-notification eh-gateway eh-frontend; do
  echo "  Starting build for ${svc}..."
  oc start-build "${svc}" -n "${PROJECT}" --follow &
done
wait
echo "  All builds complete."

# Step 5: Wait for databases to be ready
echo "[5/6] Waiting for databases..."
for ds in eh-pg eh-mysql eh-mongo eh-rabbitmq eh-redis; do
  echo "  Waiting for ${ds}..."
  oc rollout status deployment/${ds} -n "${PROJECT}" --timeout=300s || true
done

# Step 6: Update frontend config with gateway URL
echo "[6/6] Updating frontend config..."
GATEWAY_URL=$(oc get route eh-gateway -n "${PROJECT}" -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [[ -n "${GATEWAY_URL}" ]]; then
  oc patch configmap frontend-config -n "${PROJECT}" \
    -p "{\"data\":{\"config.js\":\"window.__ENV__ = { API_BASE_URL: \\\"https://${GATEWAY_URL}\\\" };\\n\"}}"
  oc rollout restart deployment/eh-frontend -n "${PROJECT}"
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Frontend:  https://$(oc get route eh-frontend -n "${PROJECT}" -o jsonpath='{.spec.host}' 2>/dev/null || echo '<pending>')"
echo "Gateway:   https://$(oc get route eh-gateway -n "${PROJECT}" -o jsonpath='{.spec.host}' 2>/dev/null || echo '<pending>')"
echo ""
echo "Run 'oc get routes -n ${PROJECT}' to see all routes."
