# Monitoring Setup

This directory contains monitoring configurations for the Kafka disaster recovery demo.

## CloudWatch Dashboard

A CloudWatch dashboard is automatically created by Terraform at:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=kafka-dr-demo-dashboard
```

The dashboard includes:
- ECS cluster CPU and memory utilization
- Producer and consumer log streams
- Custom metrics (if configured)

## Grafana Dashboard

The `grafana-dashboard.json` file can be imported into Grafana to monitor:

### Metrics Tracked
1. **Mirror Lag (Messages)** - Cluster link replication lag
2. **Producer Throughput** - Messages produced per second
3. **Consumer Lag** - Consumer group lag
4. **Consumer Throughput** - Messages consumed per second
5. **End-to-End Latency** - p95 and p99 latency measurements
6. **ECS Task Status** - Running task counts
7. **DynamoDB Throughput** - Write capacity utilization
8. **Cluster Link Status** - Active/inactive state

### Setup Instructions

#### Option 1: Hosted Grafana (Grafana Cloud)
1. Sign up at https://grafana.com/
2. Navigate to Dashboards → Import
3. Upload `grafana-dashboard.json`
4. Configure data sources:
   - Prometheus (for Kafka metrics)
   - CloudWatch (for AWS metrics)

#### Option 2: Self-Hosted Grafana
```bash
# Run Grafana in Docker
docker run -d \
  --name=grafana \
  -p 3000:3000 \
  grafana/grafana-oss:latest

# Access at http://localhost:3000
# Default credentials: admin/admin
```

### Data Source Configuration

#### Prometheus for Kafka Metrics
Configure a Prometheus data source with the Confluent Cloud metrics endpoint:
```yaml
url: https://api.telemetry.confluent.cloud/v2/metrics/cloud/export
httpHeaderName1: Content-Type
httpHeaderValue1: application/json
basicAuth: true
basicAuthUser: <API_KEY>
basicAuthPassword: <API_SECRET>
```

#### CloudWatch for AWS Metrics
Configure a CloudWatch data source:
```yaml
authType: keys
defaultRegion: us-east-1
accessKey: <AWS_ACCESS_KEY>
secretKey: <AWS_SECRET_KEY>
```

### Alerts

The dashboard includes a pre-configured alert:
- **High Mirror Lag**: Triggers when mirror lag exceeds 10,000 messages

Configure notification channels in Grafana to receive alerts via:
- Email
- Slack
- PagerDuty
- Webhook

## Custom Metrics

To emit custom metrics from the applications:

### Producer Metrics
- `kafka_producer_record_send_total` - Total records sent
- `kafka_producer_errors_total` - Total errors
- `kafka_producer_latency_ms` - Send latency

### Consumer Metrics
- `kafka_consumer_records_consumed_total` - Total records consumed
- `kafka_consumer_lag` - Consumer group lag
- `kafka_consumer_errors_total` - Total errors

### DynamoDB Metrics
CloudWatch automatically tracks:
- `ConsumedWriteCapacityUnits`
- `SystemErrors`
- `UserErrors`
- `SuccessfulRequestLatency`

## Monitoring During DR Drill

During a disaster recovery drill, monitor:

1. **Before Failover**
   - Mirror lag (should be low, < 100 messages)
   - Producer/consumer throughput (stable)
   - End-to-end latency (baseline)

2. **During Failover**
   - Mirror lag spike (expected)
   - Producer reconnection time
   - Consumer reconnection time

3. **After Failover**
   - Confirm producer writing to secondary
   - Confirm consumer reading from secondary
   - Measure new baseline metrics

4. **During Failback**
   - Reverse link mirror lag
   - Data sync progress
   - Service restart timing

## Troubleshooting

### No Data in Grafana
- Verify data source credentials
- Check Prometheus/CloudWatch connectivity
- Confirm metrics are being exported from applications

### High Mirror Lag
- Check network connectivity between regions
- Verify cluster link configuration
- Increase link replication capacity if needed

### ECS Tasks Not Running
- Check CloudWatch logs for errors
- Verify Secrets Manager permissions
- Confirm ECR image availability

## Additional Resources

- [Confluent Cloud Metrics API](https://docs.confluent.io/cloud/current/monitoring/metrics-api.html)
- [CloudWatch Metrics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/working_with_metrics.html)
- [Grafana Documentation](https://grafana.com/docs/)
