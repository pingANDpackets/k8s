#!/usr/bin/env python3
import argparse
import json
import sys
from datetime import datetime

try:
    from kafka import KafkaProducer
except ImportError as exc:
    print("kafka-python is required (pip install kafka-python)", file=sys.stderr)
    raise exc


def build_event(tenant: str, image: str, namespace: str) -> bytes:
    payload = {
        "eventType": "WebsiteCreated",
        "tenant": tenant,
        "namespace": namespace,
        "image": image,
        "timestamp": datetime.utcnow().isoformat() + "Z",
    }
    return json.dumps(payload).encode("utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Publish WebsiteCreated events to Kafka")
    parser.add_argument("tenant", help="Tenant identifier")
    parser.add_argument("image", help="Container image deployed")
    parser.add_argument("namespace", help="Kubernetes namespace")
    parser.add_argument("--bootstrap", default="localhost:9092", help="Kafka bootstrap server")
    parser.add_argument("--topic", default="website-events", help="Kafka topic name")
    args = parser.parse_args()

    producer = KafkaProducer(bootstrap_servers=args.bootstrap, value_serializer=lambda v: v)

    event_payload = build_event(args.tenant, args.image, args.namespace)
    future = producer.send(args.topic, event_payload)
    metadata = future.get(timeout=10)
    print(f"Published WebsiteCreated for {args.tenant} to partition {metadata.partition}, offset {metadata.offset}")
    producer.flush()
    producer.close()


if __name__ == "__main__":
    main()
