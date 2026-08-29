# OpenShift manifests

Apply the manifests from the repository root after building and publishing the
locally built application images (`frontend-image`, `api-gateway-image`,
`legacy-catalog-image`, `auth-service-image`, `booking-service-image`,
`ai-insight-image`, `analytics-service-image`, and `notification-worker-image`)
to a registry reachable by the cluster. Replace those image names in
`deployment.yaml` with the registry-qualified names before applying.

Create the JWT key Secret from the existing local key files; do not commit the
key material:

```sh
oc create secret generic eventhub-jwt-keys \
  --from-file=public.pem=services/api-gateway-node/public.pem \
  --from-file=private.pem=services/auth-service-node/private.pem
```

Apply the bundle:

```sh
oc apply -f infra/k8s
```

The frontend route and API gateway route receive separate hostnames. Point
`frontend/public/config.js` at the gateway route URL before building the
frontend image:

```sh
oc get route frontend api-gateway
```

The worker Service is headless because the worker consumes RabbitMQ and does
not expose an HTTP port. The five stateful dependencies use PVCs and are
intentionally single-replica deployments.
