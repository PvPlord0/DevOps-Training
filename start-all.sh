#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

PIDS=()

cleanup() {
  echo "Stopping all services..."
  for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null; done
  wait
  echo "All services stopped."
}
trap cleanup SIGINT SIGTERM EXIT

# 0. API Gateway (Node.js)
(cd "$ROOT/services/api-gateway-node" && npm start > "$LOG_DIR/gateway.log" 2>&1) &
PIDS+=($!)
echo "Started API Gateway (port 8080) — PID $!"

# 1. Legacy Catalog (Java)
(cd "$ROOT/services/legacy-catalog-java" && mvn spring-boot:run > "$LOG_DIR/catalog.log" 2>&1) &
PIDS+=($!)
echo "Started Legacy Catalog (port 8081) — PID $!"

# 2. Auth (Node.js)
(cd "$ROOT/services/auth-service-node" && node src/index.js > "$LOG_DIR/auth.log" 2>&1) &
PIDS+=($!)
echo "Started Auth (port 8082) — PID $!"

# 3. Booking (Python)
(cd "$ROOT/services/booking-service-python" && .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8083 > "$LOG_DIR/booking.log" 2>&1) &
PIDS+=($!)
echo "Started Booking (port 8083) — PID $!"

# 4. AI Insight (Python)
(cd "$ROOT/services/ai-insight-service-python" && .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8084 > "$LOG_DIR/ai-insight.log" 2>&1) &
PIDS+=($!)
echo "Started AI Insight (port 8084) — PID $!"

# 5. Analytics (Python)
(cd "$ROOT/services/analytics-service-python" && .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 8085 > "$LOG_DIR/analytics.log" 2>&1) &
PIDS+=($!)
echo "Started Analytics (port 8085) — PID $!"

# 6. Notification Worker (Go)
(cd "$ROOT/services/notification-worker-go" && go run main.go > "$LOG_DIR/notification.log" 2>&1) &
PIDS+=($!)
echo "Started Notification Worker — PID $!"

# 7. Frontend (React)
(cd "$ROOT/frontend" && npm run dev > "$LOG_DIR/frontend.log" 2>&1) &
PIDS+=($!)
echo "Started Frontend (port 3000) — PID $!"

echo ""
echo "All services started. Logs: $LOG_DIR/"
echo "Press Ctrl+C to stop all services."

wait
