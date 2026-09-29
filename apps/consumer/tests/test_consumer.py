"""Unit tests for consumer"""

import os
import json
import pytest
from unittest.mock import Mock, patch, MagicMock
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from consumer import (
    get_config,
    create_consumer_config,
    process_message,
    check_sequence_gap,
    write_to_dynamodb
)


@patch.dict(os.environ, {
    'KAFKA_BOOTSTRAP_SERVERS': 'broker.example.com:9092',
    'KAFKA_API_KEY': 'test-key',
    'KAFKA_API_SECRET': 'test-secret',
    'CONSUMER_GROUP': 'test-group',
    'DYNAMODB_TABLE': 'test-table',
    'AWS_REGION': 'us-east-1',
    'TOPIC_NAME': 'test-orders'
})
def test_get_config():
    """Test configuration loading from environment"""
    config = get_config()
    
    assert config['bootstrap_servers'] == 'broker.example.com:9092'
    assert config['api_key'] == 'test-key'
    assert config['consumer_group'] == 'test-group'
    assert config['dynamodb_table'] == 'test-table'
    assert config['aws_region'] == 'us-east-1'
    assert config['topic'] == 'test-orders'


@patch.dict(os.environ, {}, clear=True)
def test_get_config_missing_required():
    """Test that missing required variables raise ValueError"""
    with pytest.raises(ValueError, match="Missing required environment variables"):
        get_config()


@patch.dict(os.environ, {
    'KAFKA_BOOTSTRAP_SERVERS': 'broker.example.com:9092',
    'KAFKA_API_KEY': 'test-key',
    'KAFKA_API_SECRET': 'test-secret',
    'CONSUMER_GROUP': 'test-group',
    'DYNAMODB_TABLE': 'test-table',
    'AWS_REGION': 'us-east-1'
})
def test_create_consumer_config():
    """Test consumer configuration creation"""
    config = get_config()
    consumer_config = create_consumer_config(config)
    
    assert consumer_config['bootstrap.servers'] == 'broker.example.com:9092'
    assert consumer_config['group.id'] == 'test-group'
    assert consumer_config['security.protocol'] == 'SASL_SSL'
    assert consumer_config['enable.auto.commit'] is False


def test_check_sequence_gap_no_gap():
    """Test sequence checking with no gap"""
    # Reset global state
    import consumer
    consumer.last_sequence = {}
    
    gap = check_sequence_gap('order-1', 1)
    assert gap is None
    
    gap = check_sequence_gap('order-1', 2)
    assert gap is None


def test_check_sequence_gap_with_gap():
    """Test sequence checking with gap detection"""
    import consumer
    consumer.last_sequence = {}
    
    check_sequence_gap('order-1', 1)
    check_sequence_gap('order-1', 2)
    
    gap = check_sequence_gap('order-1', 5)
    assert gap == 2


def test_write_to_dynamodb():
    """Test DynamoDB write operation"""
    mock_client = Mock()
    mock_client.put_item.return_value = {}
    
    message = {
        'order_id': 'order-123',
        'timestamp_ms': 1234567890000,
        'sequence_number': 1,
        'timestamp_iso': '2024-01-01T00:00:00Z',
        'customer_id': 'customer-1',
        'product_id': 'product-1',
        'quantity': 2,
        'price': 29.99,
        'status': 'pending'
    }
    
    result = write_to_dynamodb(mock_client, 'test-table', message)
    
    assert result is True
    mock_client.put_item.assert_called_once()


def test_write_to_dynamodb_error():
    """Test DynamoDB write with error"""
    from botocore.exceptions import ClientError
    
    mock_client = Mock()
    mock_client.put_item.side_effect = ClientError(
        {'Error': {'Message': 'Table not found'}},
        'PutItem'
    )
    
    message = {
        'order_id': 'order-123',
        'timestamp_ms': 1234567890000,
        'sequence_number': 1,
        'timestamp_iso': '2024-01-01T00:00:00Z',
        'customer_id': 'customer-1',
        'product_id': 'product-1',
        'quantity': 2,
        'price': 29.99,
        'status': 'pending'
    }
    
    result = write_to_dynamodb(mock_client, 'test-table', message)
    assert result is False


@patch('consumer.write_to_dynamodb')
def test_process_message(mock_write):
    """Test message processing"""
    mock_write.return_value = True
    mock_client = Mock()
    
    message_json = json.dumps({
        'order_id': 'order-123',
        'timestamp_ms': 1234567890000,
        'sequence_number': 1,
        'timestamp_iso': '2024-01-01T00:00:00Z',
        'customer_id': 'customer-1',
        'product_id': 'product-1',
        'quantity': 2,
        'price': 29.99,
        'status': 'pending'
    })
    
    result = process_message(message_json, mock_client, 'test-table')
    assert result is True


def test_process_message_invalid_json():
    """Test message processing with invalid JSON"""
    mock_client = Mock()
    
    result = process_message('invalid json', mock_client, 'test-table')
    assert result is False
