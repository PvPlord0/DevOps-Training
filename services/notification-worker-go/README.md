# Notification worker (Go)

A pure consumer -- no HTTP API. Its only job is to prove your messaging
setup (RabbitMQ) actually works end-to-end.

## Run natively

```bash
export RABBITMQ_URL=amqp://guest:guest@localhost:5672/
export RABBITMQ_QUEUE=bookings
go run main.go
```

Requires a running RabbitMQ instance and go module dependencies fetched
(`go mod tidy`) with network access to the Go module proxy.

You'll know it's working when creating a booking via the booking service
produces a log line here within a second or two.
