#!/usr/bin/env python3
"""
Kafka Consumer for Disaster Recovery Demo
Consumes orders and writes to DynamoDB, tracks sequence numbers for loss detection
"""

import os
import sys
import json
import logging
import signal
import time
from typing import Dict, Any, Optional
from confluent_kafka import Consumer, KafkaError, KafkaException
import boto3
from botocore.exceptions import ClientError

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

shutdown_requested = False
last_sequence = {}  # Track last sequence per order_id for gap detection


def signal_handler(signum, frame):
    """Handle graceful shutdown"""
    global shutdown_requested
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_requested = True


def get_config() -> Dict[str, Any]:
    """Load configuration from environment variables"""
    required_vars = [
        "KAFKA_BOOTSTRAP_SERVERS",
        "KAFKA_API_KEY",
        "KAFKA_API_SECRET",
        "CONSUMER_GROUP",
        "DYNAMODB_TABLE",
        "AWS_REGION",
    ]

    missing = [var for var in required_vars if not os.getenv(var)]
    if missing:
        raise ValueError(
            f"Missing required environment variables: {', '.join(missing)}"
        )

    return {
        "bootstrap_servers": os.getenv("KAFKA_BOOTSTRAP_SERVERS"),
        "api_key": os.getenv("KAFKA_API_KEY"),
        "api_secret": os.getenv("KAFKA_API_SECRET"),
        "topic": os.getenv("TOPIC_NAME", "orders"),
        "consumer_group": os.getenv("CONSUMER_GROUP"),
        "dynamodb_table": os.getenv("DYNAMODB_TABLE"),
        "aws_region": os.getenv("AWS_REGION"),
        "auto_offset_reset": os.getenv("AUTO_OFFSET_RESET", "earliest"),
    }


def create_consumer_config(config: Dict[str, Any]) -> Dict[str, Any]:
    """Create Kafka consumer configuration"""
    consumer_config = {
        "bootstrap.servers": config["bootstrap_servers"],
        "security.protocol": "SASL_SSL",
        "sasl.mechanisms": "PLAIN",
        "sasl.username": config["api_key"],
        "sasl.password": config["api_secret"],
        "group.id": config["consumer_group"],
        "client.id": f"consumer-{os.getpid()}",
        "auto.offset.reset": config["auto_offset_reset"],
        "enable.auto.commit": False,
        "max.poll.interval.ms": 300000,
        "session.timeout.ms": 45000,
    }
    return consumer_config


def create_dynamodb_client(region: str):
    """Create DynamoDB client"""
    return boto3.client("dynamodb", region_name=region)


def write_to_dynamodb(
    dynamodb_client, table_name: str, message: Dict[str, Any]
) -> bool:
    """Write order message to DynamoDB"""
    try:
        item = {
            "order_id": {"S": message["order_id"]},
            "timestamp": {"N": str(message["timestamp_ms"])},
            "sequence_number": {"N": str(message["sequence_number"])},
            "timestamp_iso": {"S": message["timestamp_iso"]},
            "customer_id": {"S": message["customer_id"]},
            "product_id": {"S": message["product_id"]},
            "quantity": {"N": str(message["quantity"])},
            "price": {"N": str(message["price"])},
            "status": {"S": message["status"]},
            "consumed_at": {"N": str(int(time.time() * 1000))},
        }

        dynamodb_client.put_item(TableName=table_name, Item=item)
        return True

    except ClientError as e:
        logger.error(f"DynamoDB error: {e.response['Error']['Message']}")
        return False
    except Exception as e:
        logger.error(f"Error writing to DynamoDB: {e}", exc_info=True)
        return False


def check_sequence_gap(order_id: str, sequence: int) -> Optional[int]:
    """Check for sequence number gaps (message loss)"""
    global last_sequence

    if order_id in last_sequence:
        expected = last_sequence[order_id] + 1
        if sequence != expected:
            gap = sequence - expected
            logger.warning(
                f"Sequence gap detected for {order_id}: "
                f"expected {expected}, got {sequence} (gap: {gap} messages)"
            )
            last_sequence[order_id] = sequence
            return gap

    last_sequence[order_id] = sequence
    return None


def process_message(message_value: str, dynamodb_client, table_name: str) -> bool:
    """Process a single message"""
    try:
        message = json.loads(message_value)

        # Check for sequence gaps
        check_sequence_gap(message["order_id"], message["sequence_number"])

        # Write to DynamoDB
        success = write_to_dynamodb(dynamodb_client, table_name, message)

        if success:
            logger.debug(
                f"Processed order {message['order_id']} "
                f"(seq: {message['sequence_number']})"
            )

        return success

    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON message: {e}")
        return False
    except KeyError as e:
        logger.error(f"Missing required field in message: {e}")
        return False
    except Exception as e:
        logger.error(f"Error processing message: {e}", exc_info=True)
        return False


def run_consumer():
    """Main consumer loop"""
    global shutdown_requested

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        config = get_config()
        consumer_config = create_consumer_config(config)
        consumer = Consumer(consumer_config)
        dynamodb_client = create_dynamodb_client(config["aws_region"])

        logger.info(f"Consumer started, connecting to {config['bootstrap_servers']}")
        logger.info(f"Topic: {config['topic']}")
        logger.info(f"Consumer group: {config['consumer_group']}")
        logger.info(f"DynamoDB table: {config['dynamodb_table']}")

        consumer.subscribe([config["topic"]])

        messages_processed = 0
        last_log_time = time.time()

        while not shutdown_requested:
            try:
                msg = consumer.poll(timeout=1.0)

                if msg is None:
                    continue

                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        logger.debug(
                            f"Reached end of partition {msg.partition()} "
                            f"at offset {msg.offset()}"
                        )
                    else:
                        raise KafkaException(msg.error())
                    continue

                # Process message
                message_value = msg.value().decode("utf-8")
                success = process_message(
                    message_value, dynamodb_client, config["dynamodb_table"]
                )

                if success:
                    consumer.commit(message=msg)
                    messages_processed += 1
                else:
                    logger.error(
                        f"Failed to process message at offset {msg.offset()}, "
                        f"partition {msg.partition()}"
                    )

                # Log progress every 10 seconds
                elapsed = time.time() - last_log_time
                if elapsed >= 10:
                    rate = messages_processed / elapsed
                    logger.info(
                        f"Processed {messages_processed} messages in last {elapsed:.0f}s "
                        f"(~{rate:.0f} msg/s)"
                    )
                    messages_processed = 0
                    last_log_time = time.time()

            except KeyboardInterrupt:
                break
            except Exception as e:
                logger.error(f"Error in consumer loop: {e}", exc_info=True)
                time.sleep(1)

        logger.info("Closing consumer...")
        consumer.close()
        logger.info("Consumer shutdown complete")

    except Exception as e:
        logger.error(f"Fatal error in consumer: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    run_consumer()
