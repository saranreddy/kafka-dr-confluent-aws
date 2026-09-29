#!/usr/bin/env python3
"""
Kafka Producer for Disaster Recovery Demo
Produces keyed orders with sequence numbers and timestamps for RPO/RTO measurement
"""

import os
import sys
import time
import json
import logging
import signal
from datetime import datetime
from typing import Dict, Any
from confluent_kafka import Producer
from confluent_kafka.serialization import StringSerializer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Global sequence counter for detecting message loss
sequence_number = 0
shutdown_requested = False


def signal_handler(signum, frame):
    """Handle graceful shutdown"""
    global shutdown_requested
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown_requested = True


def get_config() -> Dict[str, Any]:
    """Load configuration from environment variables"""
    required_vars = [
        'KAFKA_BOOTSTRAP_SERVERS',
        'KAFKA_API_KEY',
        'KAFKA_API_SECRET'
    ]
    
    missing = [var for var in required_vars if not os.getenv(var)]
    if missing:
        raise ValueError(f"Missing required environment variables: {', '.join(missing)}")
    
    return {
        'bootstrap_servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS'),
        'api_key': os.getenv('KAFKA_API_KEY'),
        'api_secret': os.getenv('KAFKA_API_SECRET'),
        'topic': os.getenv('TOPIC_NAME', 'orders'),
        'messages_per_second': int(os.getenv('MESSAGES_PER_SECOND', '1000')),
        'schema_registry_url': os.getenv('SCHEMA_REGISTRY_URL'),
        'schema_registry_api_key': os.getenv('SCHEMA_REGISTRY_API_KEY'),
        'schema_registry_api_secret': os.getenv('SCHEMA_REGISTRY_API_SECRET'),
    }


def create_producer_config(config: Dict[str, Any]) -> Dict[str, Any]:
    """Create Kafka producer configuration"""
    producer_config = {
        'bootstrap.servers': config['bootstrap_servers'],
        'security.protocol': 'SASL_SSL',
        'sasl.mechanisms': 'PLAIN',
        'sasl.username': config['api_key'],
        'sasl.password': config['api_secret'],
        'client.id': f"producer-{os.getpid()}",
        'acks': 'all',
        'compression.type': 'snappy',
        'linger.ms': 10,
        'batch.size': 16384,
        'retries': 3,
        'max.in.flight.requests.per.connection': 5,
        'enable.idempotence': True,
    }
    return producer_config


def delivery_report(err, msg):
    """Callback for message delivery reports"""
    if err is not None:
        logger.error(f"Message delivery failed: {err}")
    else:
        logger.debug(
            f"Message delivered to {msg.topic()} "
            f"[partition {msg.partition()}] at offset {msg.offset()}"
        )


def generate_order_message(order_id: int, sequence: int) -> Dict[str, Any]:
    """Generate an order message with sequence number and timestamp"""
    timestamp_ms = int(time.time() * 1000)
    
    return {
        'order_id': f"order-{order_id}",
        'sequence_number': sequence,
        'timestamp_ms': timestamp_ms,
        'timestamp_iso': datetime.utcnow().isoformat() + 'Z',
        'customer_id': f"customer-{(order_id % 10000) + 1}",
        'product_id': f"product-{(order_id % 100) + 1}",
        'quantity': (order_id % 10) + 1,
        'price': round(10.0 + (order_id % 1000) / 10.0, 2),
        'status': 'pending'
    }


def run_producer():
    """Main producer loop"""
    global sequence_number, shutdown_requested
    
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    try:
        config = get_config()
        producer_config = create_producer_config(config)
        producer = Producer(producer_config)
        
        logger.info(f"Producer started, targeting {config['bootstrap_servers']}")
        logger.info(f"Topic: {config['topic']}")
        logger.info(f"Target rate: {config['messages_per_second']} messages/second")
        
        messages_per_second = config['messages_per_second']
        sleep_interval = 1.0 / messages_per_second if messages_per_second > 0 else 0
        
        order_id = 0
        last_log_time = time.time()
        messages_sent = 0
        
        while not shutdown_requested:
            try:
                order_id += 1
                sequence_number += 1
                
                message = generate_order_message(order_id, sequence_number)
                key = message['order_id']
                
                producer.produce(
                    topic=config['topic'],
                    key=key,
                    value=json.dumps(message),
                    callback=delivery_report
                )
                
                messages_sent += 1
                
                # Poll for delivery reports
                producer.poll(0)
                
                # Rate limiting
                if sleep_interval > 0:
                    time.sleep(sleep_interval)
                
                # Log progress every 10 seconds
                if time.time() - last_log_time >= 10:
                    rate = messages_sent / (time.time() - last_log_time)
                    logger.info(
                        f"Produced {messages_sent} messages in last 10s "
                        f"(~{rate:.0f} msg/s, sequence: {sequence_number})"
                    )
                    messages_sent = 0
                    last_log_time = time.time()
                    
            except KeyboardInterrupt:
                break
            except Exception as e:
                logger.error(f"Error producing message: {e}", exc_info=True)
                time.sleep(1)
        
        # Flush remaining messages
        logger.info(f"Flushing remaining messages (last sequence: {sequence_number})...")
        producer.flush(timeout=30)
        logger.info("Producer shutdown complete")
        
    except Exception as e:
        logger.error(f"Fatal error in producer: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    run_producer()
