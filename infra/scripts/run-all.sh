#!/usr/bin/env bash
set -euo pipefail

# Navigate to project root relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

# ==============================================================================
# 0. CONFIGURATION, SECRETS & RSA KEYS
# ==============================================================================
export PGUSER="${PGUSER:-auth_user}"
export PGPASSWORD="${PGPASSWORD:-auth_secure_pass}"
export PGDATABASE="${PGDATABASE:-auth_db}"

export MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root_secure_pass}"
export MYSQL_USER="${MYSQL_USER:-catalog_user}"
export MYSQL_PASSWORD="${MYSQL_PASSWORD:-catalog_pass}"
export MYSQL_DATABASE="${MYSQL_DATABASE:-catalog_db}"

export MONGO_USER="${MONGO_USER:-booking_user}"
export MONGO_PASS="${MONGO_PASS:-booking_pass}"
export MONGO_DB="${MONGO_DB:-booking_db}"

export RABBITMQ_USER="${RABBITMQ_USER:-eventhub_mq}"
export RABBITMQ_PASS="${RABBITMQ_PASS:-mq_secure_pass}"

KEYS_DIR="${KEYS_DIR:-${PROJECT_ROOT}/keys}"
mkdir -p "${KEYS_DIR}"

if [ ! -f "${KEYS_DIR}/private.pem" ]; then
    echo "Generating RSA key pair..."
    openssl genrsa -out "${KEYS_DIR}/private.pem" 2048
    openssl rsa -in "${KEYS_DIR}/private.pem" -pubout -out "${KEYS_DIR}/public.pem"
fi

MONGO_AUTH_URI="mongodb://${MONGO_USER}:${MONGO_PASS}@eventhub-mongodb:27017/${MONGO_DB}?authSource=admin"
REDIS_CONN_URL="redis://eventhub-redis:6379"

# ==============================================================================
# HELPER: Dynamic Health Check Poller
# ==============================================================================
wait_for_healthy() {
    local container_name="$1"
    local timeout="${2:-60}"
    local elapsed=0

    echo "Waiting for '$container_name' to become healthy..."
    until [ "$(podman inspect --format '{{.State.Health.Status}}' "$container_name" 2>/dev/null)" == "healthy" ]; do
        if [ "$elapsed" -ge "$timeout" ]; then
            echo "Error: '$container_name' failed to pass health check within ${timeout}s"
            podman logs "$container_name" | tail -n 25
            exit 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    echo "'$container_name' is healthy!"
}

# ==============================================================================
# 1. NETWORK CREATION
# ==============================================================================
echo "Creating Podman network..."
podman network exists eventhub-net || podman network create eventhub-net

# ==============================================================================
# 2. INFRASTRUCTURE & DATABASE CONTAINERS
# ==============================================================================
echo "Starting database and messaging infrastructure..."

pkill -9 -f mysqld 2>/dev/null || true

for container in eventhub-postgres eventhub-mysql eventhub-mongodb eventhub-redis eventhub-rabbitmq; do
    podman kill "$container" 2>/dev/null || true
    podman rm -f -t 0 "$container" 2>/dev/null || true
done

# PostgreSQL
podman run -d \
  --replace \
  --name eventhub-postgres \
  --network eventhub-net \
  -v postgres_data:/var/lib/postgresql/data \
  -e POSTGRES_USER="$PGUSER" \
  -e POSTGRES_PASSWORD="$PGPASSWORD" \
  -e POSTGRES_DB="$PGDATABASE" \
  --health-cmd="pg_isready -U $PGUSER -d $PGDATABASE" \
  --health-interval=3s \
  --health-timeout=3s \
  --health-retries=15 \
  docker.io/library/postgres:17.10

# MySQL
podman run -d \
  --replace \
  --stop-signal SIGKILL \
  --stop-timeout 1 \
  --name eventhub-mysql \
  --network eventhub-net \
  -v mysql_data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
  -e MYSQL_USER="$MYSQL_USER" \
  -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
  -e MYSQL_DATABASE="$MYSQL_DATABASE" \
  --health-cmd="mysqladmin ping -h 127.0.0.1 -u $MYSQL_USER -p$MYSQL_PASSWORD" \
  --health-interval=3s \
  --health-timeout=3s \
  --health-retries=20 \
  docker.io/library/mysql:8.4.11 \
  --innodb-flush-log-at-trx-commit=2 \
  --innodb-doublewrite=0 \
  --sync-binlog=0

# MongoDB
podman run -d \
  --replace \
  --name eventhub-mongodb \
  --network eventhub-net \
  -v mongo_data:/data/db \
  -e GLIBC_TUNABLES="glibc.pthread.rseq=1" \
  -e MONGO_INITDB_ROOT_USERNAME="$MONGO_USER" \
  -e MONGO_INITDB_ROOT_PASSWORD="$MONGO_PASS" \
  -e MONGO_INITDB_DATABASE="$MONGO_DB" \
  --health-cmd="mongosh --eval 'db.runCommand(\"ping\").ok' --quiet" \
  --health-interval=3s \
  --health-timeout=3s \
  --health-retries=15 \
  docker.io/library/mongo:8.0.28

# Redis
podman run -d \
  --replace \
  --name eventhub-redis \
  --network eventhub-net \
  -v redis_data:/data \
  --health-cmd="redis-cli ping" \
  --health-interval=3s \
  --health-timeout=3s \
  --health-retries=10 \
  docker.io/library/redis:8.0.2

# RabbitMQ
podman run -d \
  --replace \
  --name eventhub-rabbitmq \
  --network eventhub-net \
  -v rabbitmq_data:/var/lib/rabbitmq \
  -e RABBITMQ_DEFAULT_USER="$RABBITMQ_USER" \
  -e RABBITMQ_DEFAULT_PASS="$RABBITMQ_PASS" \
  --health-cmd="rabbitmq-diagnostics -q ping" \
  --health-interval=3s \
  --health-timeout=3s \
  --health-retries=20 \
  docker.io/library/rabbitmq:4.3.4-management

# Wait for databases to reach healthy state
wait_for_healthy eventhub-postgres
wait_for_healthy eventhub-mysql
wait_for_healthy eventhub-mongodb
wait_for_healthy eventhub-redis
wait_for_healthy eventhub-rabbitmq

# ==============================================================================
# 3. BUILD ALL SERVICE IMAGES
# ==============================================================================
echo "Building microservice container images..."

podman build -t auth-service -f services/auth-service-node/Containerfile services/auth-service-node/
podman build -t legacy-catalog-java -f services/legacy-catalog-java/Containerfile services/legacy-catalog-java/
podman build -t booking-service -f services/booking-service-python/Containerfile services/booking-service-python/
podman build -t ai-insights -f services/ai-insight-service-python/Containerfile services/ai-insight-service-python/
podman build -t notification-worker -f services/notification-worker-go/Containerfile services/notification-worker-go/
podman build -t analytics-service-python -f services/analytics-service-python/Containerfile services/analytics-service-python/
podman build -t api-gateway-node -f services/api-gateway-node/Containerfile services/api-gateway-node/
podman build -t frontend-react -f frontend/Containerfile frontend/

# ==============================================================================
# 4. RUN LONG-RUNNING SERVICES WITH HEALTH CHECKS
# ==============================================================================
echo "Deploying microservices..."

for service in auth-service legacy-catalog-java booking-service ai-insights notification-worker analytics-service-python api-gateway-node frontend-react; do
    podman kill "$service" 2>/dev/null || true
    podman rm -f -t 0 "$service" 2>/dev/null || true
done

# Auth Service
podman run -d \
  --replace \
  --name auth-service \
  --network eventhub-net \
  -v "${KEYS_DIR}:${KEYS_DIR}:ro,z" \
  -v /dev/null:/app/.env:ro \
  -e PGHOST=eventhub-postgres \
  -e PGUSER="$PGUSER" \
  -e PGPASSWORD="$PGPASSWORD" \
  -e PGDATABASE="$PGDATABASE" \
  -e KEYS_DIR="${KEYS_DIR}" \
  -e JWT_PRIVATE_KEY_PATH="${KEYS_DIR}/private.pem" \
  -e JWT_PUBLIC_KEY_PATH="${KEYS_DIR}/public.pem" \
  -e PRIVATE_KEY_PATH="${KEYS_DIR}/private.pem" \
  -e PUBLIC_KEY_PATH="${KEYS_DIR}/public.pem" \
  -e KEY_PATH="${KEYS_DIR}/private.pem" \
  --health-cmd="node -e \"require('http').get('http://127.0.0.1:8082/health', (r) => process.exit(0)).on('error', () => process.exit(1))\"" \
  --health-interval=5s \
  --health-retries=15 \
  auth-service

# Legacy Catalog Service
podman run -d \
  --replace \
  --name legacy-catalog-java \
  --network eventhub-net \
  -e DB_HOST=eventhub-mysql \
  -e DB_PORT=3306 \
  -e DB_USER="$MYSQL_USER" \
  -e DB_PASS="$MYSQL_PASSWORD" \
  -e DB_NAME="$MYSQL_DATABASE" \
  -e SPRING_DATASOURCE_URL="jdbc:mysql://eventhub-mysql:3306/${MYSQL_DATABASE}?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=UTC" \
  -e SPRING_DATASOURCE_USERNAME="$MYSQL_USER" \
  -e SPRING_DATASOURCE_PASSWORD="$MYSQL_PASSWORD" \
  -e SPRING_JPA_PROPERTIES_HIBERNATE_DIALECT="org.hibernate.dialect.MySQL8Dialect" \
  --health-cmd="nc -z localhost 8081 || exit 1" \
  --health-interval=5s \
  --health-retries=20 \
  legacy-catalog-java

# Booking Service
podman run -d \
  --replace \
  --name booking-service \
  --network eventhub-net \
  -e MONGO_HOST=eventhub-mongodb \
  -e MONGODB_HOST=eventhub-mongodb \
  -e MONGO_PORT=27017 \
  -e MONGODB_PORT=27017 \
  -e MONGO_USER="$MONGO_USER" \
  -e MONGO_PASS="$MONGO_PASS" \
  -e MONGO_DB="$MONGO_DB" \
  -e MONGODB_DB="$MONGO_DB" \
  -e MONGO_URI="$MONGO_AUTH_URI" \
  -e MONGODB_URI="$MONGO_AUTH_URI" \
  -e MONGO_URL="$MONGO_AUTH_URI" \
  -e MONGODB_URL="$MONGO_AUTH_URI" \
  -e AI_INSIGHT_URL="http://ai-insights:8084" \
  --health-cmd="python -c \"import socket; socket.create_connection(('127.0.0.1', 8083), timeout=2)\"" \
  --health-interval=5s \
  --health-retries=15 \
  booking-service

# AI Insights
podman run -d \
  --replace \
  --name ai-insights \
  --network eventhub-net \
  --health-cmd="python -c \"import socket; socket.create_connection(('127.0.0.1', 8084), timeout=2)\"" \
  --health-interval=5s \
  --health-retries=15 \
  ai-insights

# Notification Worker
podman run -d \
  --replace \
  --name notification-worker \
  --network eventhub-net \
  -e RABBITMQ_HOST=eventhub-rabbitmq \
  -e RABBITMQ_USER="$RABBITMQ_USER" \
  -e RABBITMQ_PASS="$RABBITMQ_PASS" \
  --health-cmd="pgrep -f notification || exit 1" \
  --health-interval=5s \
  --health-retries=10 \
  notification-worker

# Analytics API Service
podman run -d \
  --replace \
  --name analytics-service-python \
  --network eventhub-net \
  -e REDIS_HOST=eventhub-redis \
  -e REDIS_HOSTNAME=eventhub-redis \
  -e REDIS_PORT=6379 \
  -e REDIS_URL="$REDIS_CONN_URL" \
  -e REDIS_URI="$REDIS_CONN_URL" \
  -e CATALOG_SERVICE_URL=http://legacy-catalog-java:8081 \
  -e BOOKING_SERVICE_URL=http://booking-service:8083 \
  --health-cmd="python -c \"import socket; socket.create_connection(('127.0.0.1', 8085), timeout=2)\"" \
  --health-interval=5s \
  --health-retries=15 \
  analytics-service-python

# API Gateway
podman run -d \
  --replace \
  --name api-gateway-node \
  --network eventhub-net \
  -p 8080:8080 \
  -v "${KEYS_DIR}:${KEYS_DIR}:ro,z" \
  -v /dev/null:/app/.env:ro \
  -e KEYS_DIR="${KEYS_DIR}" \
  -e JWT_PUBLIC_KEY_PATH="${KEYS_DIR}/public.pem" \
  -e PUBLIC_KEY_PATH="${KEYS_DIR}/public.pem" \
  -e JWT_PRIVATE_KEY_PATH="${KEYS_DIR}/private.pem" \
  -e PRIVATE_KEY_PATH="${KEYS_DIR}/private.pem" \
  -e KEY_PATH="${KEYS_DIR}/public.pem" \
  -e CATALOG_SERVICE_URL=http://legacy-catalog-java:8081 \
  -e AUTH_SERVICE_URL=http://auth-service:8082 \
  -e BOOKING_SERVICE_URL=http://booking-service:8083 \
  -e AI_SERVICE_URL=http://ai-insights:8084 \
  -e ANALYTICS_SERVICE_URL=http://analytics-service-python:8085 \
  --health-cmd="node -e \"require('http').get('http://127.0.0.1:8080/health', (r) => process.exit(0)).on('error', () => process.exit(1))\"" \
  --health-interval=5s \
  --health-retries=15 \
  api-gateway-node

# Frontend UI
podman run -d \
  --replace \
  --name frontend-react \
  --network eventhub-net \
  -p 3000:3000 \
  -v /dev/null:/app/.env:ro \
  --health-cmd="node -e \"require('http').get('http://127.0.0.1:3000/', (r) => process.exit(0)).on('error', () => process.exit(1))\"" \
  --health-interval=5s \
  --health-retries=15 \
  frontend-react

# Wait for essential services
wait_for_healthy auth-service
wait_for_healthy legacy-catalog-java
wait_for_healthy booking-service
wait_for_healthy analytics-service-python
wait_for_healthy api-gateway-node

# ==============================================================================
# 5. RUN ONE-OFF ANALYTICS INITIALIZATION JOB
# ==============================================================================
echo "Running initial analytics snapshot batch job..."

podman run --rm \
  --network eventhub-net \
  -e REDIS_HOST=eventhub-redis \
  -e REDIS_HOSTNAME=eventhub-redis \
  -e REDIS_PORT=6379 \
  -e REDIS_URL="$REDIS_CONN_URL" \
  -e REDIS_URI="$REDIS_CONN_URL" \
  -e CATALOG_SERVICE_URL=http://legacy-catalog-java:8081 \
  -e BOOKING_SERVICE_URL=http://booking-service:8083 \
  analytics-service-python python job.py

echo "EventHub stack successfully deployed!"
