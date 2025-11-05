#!/usr/bin/env python3
import argparse
import json
import sys

try:
    from kafka import KafkaConsumer
except ImportError as exc:
    print("kafka-python is required (pip install kafka-python)", file=sys.stderr)
    raise exc


def main() -> None:
    parser = argparse.ArgumentParser(description="Consume WebsiteCreated events from Kafka")
    parser.add_argument("--bootstrap", default="localhost:9092", help="Kafka bootstrap server")
    parser.add_argument("--topic", default="website-events", help="Kafka topic name")
    parser.add_argument("--group", default="website-events-consumer", help="Consumer group id")
    args = parser.parse_args()

    consumer = KafkaConsumer(
        args.topic,
        bootstrap_servers=args.bootstrap,
        group_id=args.group,
        auto_offset_reset="earliest",
        value_deserializer=lambda v: json.loads(v.decode("utf-8")),
    )

    print(f"📥 Listening for events on topic '{args.topic}'...")
    try:
        for message in consumer:
            print(json.dumps(message.value, indent=2))
    except KeyboardInterrupt:
        print("Stopping consumer...")
    finally:
        consumer.close()


if __name__ == "__main__":
    main()
