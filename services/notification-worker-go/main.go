package main

import (
	"encoding/json"
	"log"
	"os"

	amqp "github.com/rabbitmq/amqp091-go"
)

type BookingEvent struct {
	BookingID string `json:"bookingId"`
	UserID    string `json:"userId"`
	EventID   int    `json:"eventId"`
}

func main() {
	url := os.Getenv("RABBITMQ_URL")
	if url == "" {
		url = "amqp://guest:guest@localhost:5672/"
	}
	queue := os.Getenv("RABBITMQ_QUEUE")
	if queue == "" {
		queue = "bookings"
	}

	conn, err := amqp.Dial(url)
	if err != nil {
		log.Fatalf("failed to connect to rabbitmq: %v", err)
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		log.Fatalf("failed to open channel: %v", err)
	}
	defer ch.Close()

	_, err = ch.QueueDeclare(queue, true, false, false, false, nil)
	if err != nil {
		log.Fatalf("failed to declare queue: %v", err)
	}

	msgs, err := ch.Consume(queue, "", true, false, false, false, nil)
	if err != nil {
		log.Fatalf("failed to register consumer: %v", err)
	}

	log.Printf("notification-worker listening on queue %q", queue)

	for msg := range msgs {
		var event BookingEvent
		if err := json.Unmarshal(msg.Body, &event); err != nil {
			log.Printf("skipping malformed message: %v", err)
			continue
		}
		// Real notification sending (email/SMS) is intentionally out of
		// scope -- log it clearly enough to prove the pipeline works.
		log.Printf("notification: booking %s confirmed for user %s (event %d)",
			event.BookingID, event.UserID, event.EventID)
	}
}
