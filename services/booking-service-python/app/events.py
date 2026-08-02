import json
import logging
import os

import pika

logger = logging.getLogger(__name__)


def publish_booking_created(booking: dict):
    """Publish a booking-created event. Logs and swallows connection errors
    so that booking creation still succeeds locally even before RabbitMQ is
    wired up in phase 2 -- but check the logs, this is not something to
    silently ignore forever."""
    url = os.environ.get("RABBITMQ_URL")
    queue = os.environ.get("RABBITMQ_QUEUE", "bookings")
    if not url:
        logger.warning("RABBITMQ_URL not set, skipping event publish for booking %s", booking.get("id"))
        return
    try:
        connection = pika.BlockingConnection(pika.URLParameters(url))
        channel = connection.channel()
        channel.queue_declare(queue=queue, durable=True)
        channel.basic_publish(exchange="", routing_key=queue, body=json.dumps(booking))
        connection.close()
    except Exception as exc:
        logger.error("failed to publish booking event: %s", exc)
