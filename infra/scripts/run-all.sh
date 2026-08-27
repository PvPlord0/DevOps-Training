#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

containers=(
    mysql
    postgres
    rabbitmq
    mongodb
    redis
    frontend
    api-gateway
    legacy-catalog
    auth-service
    booking-service
    ai-insight
    analytics-service
    notification-worker
)

cleanup() {
    echo
    echo "Interrupt received. Stopping and removing EventHub containers..."
    podman rm -f "${containers[@]}" >/dev/null 2>&1 || true
    exit 130
}

trap cleanup INT TERM

start_container() {
    local name=$1
    local container_id
    shift
    echo "Starting container: $name"
    container_id=$(podman run -d --name "$name" "$@") || return
    echo "Started container: $name ($container_id)"
}

build_if_missing() {
    local image=$1
    local containerfile=$2
    local context=$3

    if podman image exists "$image"; then
        echo "Using existing image: $image"
    else
        echo "Building image: $image"
        podman build -t "$image" -f "$containerfile" "$context"
    fi
}

podman network exists eventhub-net || podman network create eventhub-net

start_container mysql \
   --network eventhub-net \
    -p 3306:3306 \
    -e MYSQL_ROOT_PASSWORD=rootpassword \
    -e MYSQL_DATABASE=eventhub_catalog \
    -v mysql-data:/var/lib/mysql \
        docker.io/library/mysql:8.4

start_container postgres \
    --network eventhub-net \
    -p 5432:5432 \
    -e POSTGRES_USER=eventhub \
    -e POSTGRES_PASSWORD=eventhub \
    -e POSTGRES_DB=eventhub_auth \
    -v pgdata:/var/lib/postgresql/data \
        postgres:16-alpine

start_container rabbitmq \
    --network eventhub-net \
    -p 15672:15672 \
    -e RABBITMQ_DEFAULT_USER=eventhub \
    -e RABBITMQ_DEFAULT_PASS=eventhub-password \
    -v rabbitmq-data:/var/lib/rabbitmq \
        docker.io/library/rabbitmq:3-management-alpine

start_container mongodb \
    --network eventhub-net \
    -p 27017:27017 \
    -e MONGO_INITDB_DATABASE=eventhub_bookings \
    -v mongodb-data:/data/db \
        docker.io/library/mongo:7


start_container redis \
    --network eventhub-net \
    -p 6379:6379 \
    -v redis-data:/data \
        docker.io/library/redis:7-alpine \
            redis-server --appendonly yes


build_if_missing frontend-image \
    "$REPO_ROOT/frontend/Containerfile" \
    "$REPO_ROOT/frontend" && \
    start_container frontend \
    --network eventhub-net \
    -p 3000:3000 \
    -e VITE_API_BASE_URL=http://localhost:8080 \
        frontend-image


build_if_missing api-gateway-image \
    "$REPO_ROOT/services/api-gateway-node/Containerfile" \
    "$REPO_ROOT/services/api-gateway-node" && \
    start_container api-gateway \
    --network eventhub-net \
    -p 8080:8080 \
    -e FRONTEND_URL=http://localhost:3000 \
    -e JWT_PUBLIC_KEY_PATH=/app/keys/public.pem \
    -v "$REPO_ROOT/services/api-gateway-node/public.pem":/app/keys/public.pem \
        api-gateway-image


until podman exec mysql mysqladmin ping -h "mysql" --silent; do
    echo "Waiting for MySQL to be ready..."
    sleep 2
done

if ! podman exec mysql mysql -uroot -prootpassword -Nse \
    "SELECT COUNT(*) FROM eventhub_catalog.catalog_event" | grep -qv '^4$'; then
    echo "MySQL seed already present"
else
    echo "Seeding MySQL"
    podman exec -i mysql mysql -uroot -prootpassword \
        < "$REPO_ROOT/db-seed/mysql-seed.sql"
fi

build_if_missing legacy-catalog-image \
    "$REPO_ROOT/services/legacy-catalog-java/Containerfile" \
    "$REPO_ROOT/services/legacy-catalog-java" && \
    start_container legacy-catalog \
    --network eventhub-net \
    -p 8081:8081 \
    -e SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/eventhub_catalog \
    -e SPRING_DATASOURCE_USERNAME=root \
    -e SPRING_DATASOURCE_PASSWORD=rootpassword \
        legacy-catalog-image


until podman exec postgres pg_isready -U eventhub -d eventhub_auth; do
    echo "Waiting for PostgreSQL to be ready..."
    sleep 2
done

build_if_missing auth-service-image \
    "$REPO_ROOT/services/auth-service-node/Containerfile" \
    "$REPO_ROOT/services/auth-service-node" && \
    start_container auth-service \
    --network eventhub-net \
    -p 8082:8082 \
    -e JWT_PRIVATE_KEY_PATH=/app/keys/private.pem \
    -e PGHOST=postgres \
    -e PGPORT=5432 \
    -e PGUSER=eventhub \
    -e PGPASSWORD=eventhub \
    -e PGDATABASE=eventhub_auth \
    -v "$REPO_ROOT/services/auth-service-node/private.pem":/app/keys/private.pem \
        auth-service-image


until podman exec mongodb mongosh --quiet --eval "db.adminCommand('ping').ok" | grep -q "1"; do
    echo "Waiting for MongoDB to be ready..."
    sleep 2
done

if podman exec mongodb mongosh eventhub_bookings --quiet --eval \
    "db.bookings.countDocuments({})" | grep -q '^2$'; then
    echo "MongoDB seed already present"
else
    echo "Seeding MongoDB"
    podman exec -i mongodb mongosh eventhub_bookings \
        < "$REPO_ROOT/db-seed/mongo-seed.js"
fi

until podman exec rabbitmq rabbitmqctl status; do
    echo "Waiting for RabbitMQ to be ready..."
    sleep 2
done


build_if_missing booking-service-image \
    "$REPO_ROOT/services/booking-service-python/Containerfile" \
    "$REPO_ROOT/services/booking-service-python" && \
    start_container booking-service \
    --network eventhub-net \
    -p 8083:8083 \
    -e MONGO_URI=mongodb://mongodb:27017/eventhub_bookings \
    -e MONGO_DB=eventhub_bookings \
    -e RABBITMQ_URL=amqp://guest:guest@rabbitmq:5672/ \
    -e RABBITMQ_QUEUE=bookings \
    -e AI_INSIGHT_URL=http://ai-insight:8084 \
        booking-service-image



build_if_missing ai-insight-service-image \
    "$REPO_ROOT/services/ai-insight-service-python/Containerfile" \
    "$REPO_ROOT/services/ai-insight-service-python" && \
    start_container ai-insight \
    --network eventhub-net \
    -p 8084:8084 \
        ai-insight-service-image


until podman exec redis redis-cli ping; do
    echo "Waiting for Redis to be ready..."
    sleep 2
done



build_if_missing analytics-service-image \
    "$REPO_ROOT/services/analytics-service-python/Containerfile" \
    "$REPO_ROOT/services/analytics-service-python" && \
    start_container analytics-service \
    --network eventhub-net \
    -p 8085:8085 \
    -e REDIS_HOST=redis \
    -e REDIS_PORT=6379 \
    -e REDIS_URL=redis://redis:6379/0 \
    -e BOOKING_SERVICE_URL=http://booking-service:8083 \
    -e CATALOG_SERVICE_URL=http://legacy-catalog:8081 \
    -e SNAPSHOT_KEY=analytics:snapshot \
        analytics-service-image

build_if_missing notification-worker-image \
    "$REPO_ROOT/services/notification-worker-go/Containerfile" \
    "$REPO_ROOT/services/notification-worker-go" && \
    start_container notification-worker \
    --network eventhub-net \
    -e RABBITMQ_URL=amqp://eventhub:eventhub-password@rabbitmq:5672/ \
    -e RABBITMQ_QUEUE=bookings \
        notification-worker-image

podman exec analytics-service python job.py 

echo ""
echo "Press Ctrl+C to stop all Containers."

while true; do
    sleep 1
done