#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

if ! { [[ -d "${ROOT}/keys" ]] && [[ -f "${ROOT}/keys/public.pem" ]] && [[ -f "${ROOT}/keys/private.pem" ]]; }; then
  echo "Keys not found in ${ROOT}/keys. Please create the keys and place them in the keys directory."
  exit 1
fi

wait_for_port() {
  local name=$1 port=$2
  echo "  Waiting for $name..."
  until podman exec "$name" sh -c "nc -z localhost $port 2>/dev/null || python -c \"import socket; s=socket.socket(); s.connect(('localhost',$port)); s.close()\"" 2>/dev/null; do
    sleep 1
  done
}

# Create network
echo "Creating network..."
if ! podman network exists eventhub-net; then
  podman network create eventhub-net
fi

# Create volumes & load data if available
echo "Creating volumes..."
if ! podman volume exists eh-pg-data; then
  podman volume create eh-pg-data
  if [ -f "${ROOT}/infra/volumes/pg-data.tar" ]; then
    podman volume import eh-pg-data "${ROOT}/infra/volumes/pg-data.tar"
  fi
fi

if ! podman volume exists eh-mysql-data; then
  podman volume create eh-mysql-data
  if [ -f "${ROOT}/infra/volumes/mysql-data.tar" ]; then
    podman volume import eh-mysql-data "${ROOT}/infra/volumes/mysql-data.tar"
  fi
fi

if ! podman volume exists eh-mongo-data; then
  podman volume create eh-mongo-data
  if [ -f "${ROOT}/infra/volumes/mongo-data.tar" ]; then
    podman volume import eh-mongo-data "${ROOT}/infra/volumes/mongo-data.tar"
  fi
fi

if ! podman volume exists eh-rabbitmq-data; then
  podman volume create eh-rabbitmq-data
  if [ -f "${ROOT}/infra/volumes/rabbitmq-data.tar" ]; then
    podman volume import eh-rabbitmq-data "${ROOT}/infra/volumes/rabbitmq-data.tar"
  fi
fi

if ! podman volume exists eh-redis-data; then
  podman volume create eh-redis-data
  if [ -f "${ROOT}/infra/volumes/redis-data.tar" ]; then
    podman volume import eh-redis-data "${ROOT}/infra/volumes/redis-data.tar"
  fi
fi

# Build all service images
echo "Building service images..."
podman build --format docker -t eh-frontend     "${ROOT}/frontend"
podman build --format docker -t eh-gateway      "${ROOT}/services/api-gateway-node"
podman build --format docker -t eh-auth         "${ROOT}/services/auth-service-node"
podman build --format docker -t eh-catalog      "${ROOT}/services/legacy-catalog-java"
podman build --format docker -t eh-booking      "${ROOT}/services/booking-service-python"
podman build --format docker -t eh-analytics    "${ROOT}/services/analytics-service-python"
podman build --format docker -t eh-insight      "${ROOT}/services/ai-insight-service-python"
podman build --format docker -t eh-notification "${ROOT}/services/notification-worker-go"
echo "Build complete."

# Start databases
echo "Starting databases..."
podman run -d --name eh-pg --net eventhub-net \
  -e POSTGRES_USER=eventhub \
  -e POSTGRES_PASSWORD=eventhub \
  -e POSTGRES_DB=eventhub_auth \
  -v eh-pg-data:/var/lib/postgresql/data:Z \
  postgres:17.10-alpine3.24

podman run -d --name eh-mysql --net eventhub-net \
  -e MYSQL_ROOT_PASSWORD='rootpassword' \
  -e MYSQL_DATABASE='eventhub_catalog' \
  -v eh-mysql-data:/var/lib/mysql:Z \
  mysql:8.4.11

podman run -d --name eh-mongo --net eventhub-net \
  -v eh-mongo-data:/data/db:Z \
  mongo:8.0.28

podman run -d --name eh-rabbitmq --net eventhub-net \
  -v eh-rabbitmq-data:/var/lib/rabbitmq:Z \
  rabbitmq:4.3.4-alpine

podman run -d --name eh-redis --net eventhub-net \
  -v eh-redis-data:/data:Z \
  redis:8.0.2-alpine

# Wait for databases to be ready
echo "Waiting for databases..."
until podman exec eh-pg      pg_isready -U eventhub > /dev/null 2>&1; do sleep 1; done
until podman exec eh-mysql   mysqladmin ping --silent > /dev/null 2>&1; do sleep 1; done
until podman exec eh-mongo   mongosh --eval 'db.runCommand("ping").ok' --quiet > /dev/null 2>&1; do sleep 1; done
until podman exec eh-rabbitmq rabbitmqctl status > /dev/null 2>&1; do sleep 1; done
until podman exec eh-redis   redis-cli ping > /dev/null 2>&1; do sleep 1; done
echo "Databases ready."

# Start services
echo "Starting services..."
podman run -d -p 3000:3000 --net eventhub-net \
  --name eh-frontend-cont \
  eh-frontend

podman run -d --net eventhub-net \
  --name eh-gateway-cont \
  -p 8080:8080 \
  -e FRONTEND_URL=http://localhost:3000 \
  -e ROUTE__API_CATALOG=http://eh-catalog-cont:8081 \
  -e ROUTE__API_AUTH=http://eh-auth-cont:8082 \
  -e ROUTE__API_BOOKINGS=http://eh-booking-cont:8083 \
  -e ROUTE__API_REVIEWS=http://eh-booking-cont:8083 \
  -e ROUTE__API_ANALYZE=http://eh-insight-cont:8084 \
  -e ROUTE__API_ANALYTICS=http://eh-analytics-cont:8085 \
  -e JWT_PUBLIC_KEY_PATH=/app/keys/public.pem \
  -v "${ROOT}/keys/public.pem:/app/keys/public.pem:Z,ro" \
  eh-gateway

podman run -d --net eventhub-net \
  --name eh-insight-cont \
  -e OLLAMA_URL="${OLLAMA_URL:-}" \
  -e OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2:1b}" \
  eh-insight

podman run -d --net eventhub-net \
  --name eh-auth-cont \
  -e PGHOST=eh-pg \
  -e PGPORT=5432 \
  -e PGUSER=eventhub \
  -e PGPASSWORD=eventhub \
  -e PGDATABASE=eventhub_auth \
  -e JWT_PRIVATE_KEY_PATH=/app/keys/private.pem \
  -v "${ROOT}/keys/private.pem:/app/keys/private.pem:Z,ro" \
  eh-auth

podman run -d --net eventhub-net \
  --name eh-catalog-cont \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://eh-mysql:3306/eventhub_catalog \
  -e SPRING_DATASOURCE_USERNAME=root \
  -e SPRING_DATASOURCE_PASSWORD=rootpassword \
  eh-catalog

podman run -d --net eventhub-net \
  --name eh-notification-cont \
  -e RABBITMQ_URL=amqp://guest:guest@eh-rabbitmq:5672/ \
  -e RABBITMQ_QUEUE=bookings \
  eh-notification

wait_for_port eh-insight-cont 8084

podman run -d --net eventhub-net \
  --name eh-booking-cont \
  -e MONGO_URI=mongodb://eh-mongo:27017 \
  -e MONGO_DB=eventhub_bookings \
  -e RABBITMQ_URL=amqp://guest:guest@eh-rabbitmq:5672/ \
  -e RABBITMQ_QUEUE=bookings \
  -e AI_INSIGHT_URL=http://eh-insight-cont:8084 \
  eh-booking

wait_for_port eh-booking-cont 8083
wait_for_port eh-catalog-cont 8081

podman run -d --net eventhub-net \
  --name eh-analytics-cont \
  -e REDIS_URL=redis://eh-redis:6379/0 \
  -e BOOKING_SERVICE_URL=http://eh-booking-cont:8083 \
  -e CATALOG_SERVICE_URL=http://eh-catalog-cont:8081 \
  -e SNAPSHOT_KEY=analytics:snapshot \
  eh-analytics

# Run analytics job once to seed dashboard data
echo "Running analytics snapshot job..."
podman run --rm --net eventhub-net \
  --name eh-analytics-job \
  -e REDIS_URL=redis://eh-redis:6379/0 \
  -e BOOKING_SERVICE_URL=http://eh-booking-cont:8083 \
  -e CATALOG_SERVICE_URL=http://eh-catalog-cont:8081 \
  -e SNAPSHOT_KEY=analytics:snapshot \
  eh-analytics python job.py

echo "All services started. Dashboard available at http://localhost:3000"
