"""Unit tests for producer"""

import os
import pytest
from unittest.mock import Mock, patch
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from producer import (
    get_config,
    create_producer_config,
    generate_order_message,
    delivery_report
)


def test_generate_order_message():
    """Test order message generation"""
    message = generate_order_message(order_id=123, sequence=456)
    
    assert message['order_id'] == 'order-123'
    assert message['sequence_number'] == 456
    assert 'timestamp_ms' in message
    assert 'timestamp_iso' in message
    assert message['customer_id'].startswith('customer-')
    assert message['product_id'].startswith('product-')
    assert message['quantity'] >= 1
    assert message['price'] > 0
    assert message['status'] == 'pending'


def test_generate_order_message_consistency():
    """Test that same order_id generates consistent customer/product references"""
    msg1 = generate_order_message(order_id=100, sequence=1)
    msg2 = generate_order_message(order_id=100, sequence=2)
    
    assert msg1['customer_id'] == msg2['customer_id']
    assert msg1['product_id'] == msg2['product_id']


@patch.dict(os.environ, {
    'KAFKA_BOOTSTRAP_SERVERS': 'broker.example.com:9092',
    'KAFKA_API_KEY': 'test-key',
    'KAFKA_API_SECRET': 'test-secret',
    'TOPIC_NAME': 'test-orders',
    'MESSAGES_PER_SECOND': '500'
})
def test_get_config():
    """Test configuration loading from environment"""
    config = get_config()
    
    assert config['bootstrap_servers'] == 'broker.example.com:9092'
    assert config['api_key'] == 'test-key'
    assert config['api_secret'] == 'test-secret'
    assert config['topic'] == 'test-orders'
    assert config['messages_per_second'] == 500


@patch.dict(os.environ, {}, clear=True)
def test_get_config_missing_required():
    """Test that missing required variables raise ValueError"""
    with pytest.raises(ValueError, match="Missing required environment variables"):
        get_config()


@patch.dict(os.environ, {
    'KAFKA_BOOTSTRAP_SERVERS': 'broker.example.com:9092',
    'KAFKA_API_KEY': 'test-key',
    'KAFKA_API_SECRET': 'test-secret'
})
def test_create_producer_config():
    """Test producer configuration creation"""
    config = get_config()
    producer_config = create_producer_config(config)
    
    assert producer_config['bootstrap.servers'] == 'broker.example.com:9092'
    assert producer_config['security.protocol'] == 'SASL_SSL'
    assert producer_config['sasl.mechanisms'] == 'PLAIN'
    assert producer_config['sasl.username'] == 'test-key'
    assert producer_config['sasl.password'] == 'test-secret'
    assert producer_config['acks'] == 'all'
    assert producer_config['enable.idempotence'] is True


def test_delivery_report_success():
    """Test delivery report callback with successful delivery"""
    mock_msg = Mock()
    mock_msg.topic.return_value = 'orders'
    mock_msg.partition.return_value = 2
    mock_msg.offset.return_value = 12345
    
    delivery_report(None, mock_msg)


def test_delivery_report_error():
    """Test delivery report callback with error"""
    mock_error = Mock()
    mock_error.__str__ = lambda self: "Connection timeout"
    
    delivery_report(mock_error, None)
