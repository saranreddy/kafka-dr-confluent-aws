# Cluster Linking vs MirrorMaker 2 Comparison

## Overview

This document compares two disaster recovery solutions for Apache Kafka:
1. **Confluent Cloud Cluster Linking** (primary implementation)
2. **MirrorMaker 2 on Amazon MSK Connect** (alternative comparison)

## Architecture Comparison

### Cluster Linking (Confluent Cloud)
```
┌─────────────────────────────────────┐       ┌─────────────────────────────────────┐
│   Primary Region (us-east-1)        │       │   Secondary Region (us-west-2)      │
│                                     │       │                                     │
│  ┌──────────────────────────────┐  │       │  ┌──────────────────────────────┐  │
│  │  Confluent Cloud Cluster     │  │       │  │  Confluent Cloud Cluster     │  │
│  │  - orders (source topic)     │──┼───────┼─>│  - orders (mirror topic)     │  │
│  │  - Consumer offsets tracked  │  │       │  │  - Consumer offsets synced   │  │
│  └──────────────────────────────┘  │       │  └──────────────────────────────┘  │
│           ▲           │             │       │              │                      │
│           │           ▼             │       │              ▼                      │
│      Producer    Consumer           │       │         Consumer (standby)          │
└─────────────────────────────────────┘       └─────────────────────────────────────┘
         Cluster Link (Native Kafka Protocol, Consumer Offset Sync)
```

### MirrorMaker 2 (Amazon MSK)
```
┌─────────────────────────────────────┐       ┌─────────────────────────────────────┐
│   Primary Region (us-east-1)        │       │   Secondary Region (us-west-2)      │
│                                     │       │                                     │
│  ┌──────────────────────────────┐  │       │  ┌──────────────────────────────┐  │
│  │  Amazon MSK Cluster          │  │       │  │  Amazon MSK Cluster          │  │
│  │  - orders (source topic)     │  │       │  │  - primary.orders (mirror)   │  │
│  └──────────────────────────────┘  │       │  └──────────────────────────────┘  │
│           ▲           │             │       │              │                      │
│           │           ▼             │       │              ▼                      │
│      Producer    Consumer           │       │         Consumer (standby)          │
│                                     │       │                                     │
│  ┌──────────────────────────────┐  │       │                                     │
│  │  MSK Connect                 │  │       │                                     │
│  │  - MirrorMaker 2 Connector   │──┼───────┼──────────────────────────>          │
│  │  - Checkpoint Connector      │  │       │                                     │
│  │  - Heartbeat Connector       │  │       │                                     │
│  └──────────────────────────────┘  │       │                                     │
└─────────────────────────────────────┘       └─────────────────────────────────────┘
         MirrorMaker 2 (Kafka Connect Protocol, Separate Offset Translation)
```

## Feature Comparison

| Feature | Cluster Linking | MirrorMaker 2 |
|---------|----------------|---------------|
| **Consumer Offset Sync** | Native, automatic | Via checkpoint connector |
| **Topic Naming** | Mirror preserves name | Adds source cluster prefix |
| **Failover Complexity** | Simple (promote mirror) | Manual (offset translation) |
| **Replication Lag** | < 100ms typical | 1-5s typical |
| **Configuration** | Managed by Confluent | Self-managed (MSK Connect) |
| **Schema Registry Sync** | Built-in Schema Linking | Manual setup required |
| **ACL Sync** | Automatic | Manual configuration |
| **Exactly-once Semantics** | Preserved | Lost across clusters |
| **Bi-directional Replication** | Supported | Requires 2 connectors |
| **Topic Filtering** | Pattern-based | Pattern-based |
| **Metadata Sync** | Full (configs, ACLs) | Limited (topics only) |

## Performance Comparison

### Test Methodology

#### Common Setup
- **Topic**: orders, 6 partitions, replication factor 3
- **Producer**: 1,000 messages/second, 1KB average message size
- **Duration**: 1 hour steady state, then failover
- **Measurements**: RPO (messages lost), RTO (seconds to recover)

#### Cluster Linking Test
1. Configure cluster link with consumer offset sync enabled
2. Run producer and consumer on primary
3. Verify mirror lag < 100 messages
4. Simulate primary failure
5. Promote mirror topic on secondary
6. Update client configs to point to secondary
7. Measure time to resume and messages lost

#### MirrorMaker 2 Test
1. Deploy MM2 connector on MSK Connect
2. Run producer and consumer on primary
3. Verify replication lag < 1000 messages
4. Simulate primary failure
5. Translate consumer offsets from checkpoints
6. Update client configs to point to secondary (with prefix)
7. Measure time to resume and messages lost

### Expected Results (Placeholder - Requires Real Infrastructure)

| Metric | Cluster Linking | MirrorMaker 2 |
|--------|----------------|---------------|
| **Steady-State Lag** | [TBD: 50-100 messages] | [TBD: 500-1000 messages] |
| **RPO (Messages Lost)** | [TBD: 0-10] | [TBD: 50-200] |
| **RTO (Seconds)** | [TBD: 30-45s] | [TBD: 120-180s] |
| **Failover Steps** | [TBD: 3 steps] | [TBD: 5-6 steps] |
| **Automation Feasible** | [TBD: Yes] | [TBD: Partial] |

**Note**: These are placeholder values. Actual testing requires:
1. Deployed infrastructure with real traffic
2. Multiple failover scenarios
3. Statistical analysis over multiple runs

## Cost Comparison

**Note:** All costs are rough estimates as of September 2024 for demonstration purposes. Actual costs vary by region, usage patterns, and current pricing. Always consult official pricing pages before deployment.

**Pricing References:**
- [Confluent Cloud Pricing](https://www.confluent.io/confluent-cloud/pricing/)
- [Amazon MSK Pricing](https://aws.amazon.com/msk/pricing/)
- [AWS MSK Connect Pricing](https://aws.amazon.com/msk/pricing/)
- [AWS Data Transfer Pricing](https://aws.amazon.com/ec2/pricing/on-demand/#Data_Transfer)

### Cluster Linking (Confluent Cloud)

#### Monthly Costs (Estimate)
- **Primary Cluster (Basic)**: ~$1/hour = $720/month
- **Secondary Cluster (Basic)**: ~$1/hour = $720/month
- **Cluster Link**: ~$0.10/GB replicated
  - At 1,000 msg/s × 1KB × 30 days = ~2.5 TB/month
  - Cost: ~$250/month
- **Schema Registry**: Included in cluster cost
- **Total**: ~$1,690/month

**Pros**:
- No infrastructure management
- Includes monitoring and support
- Elastic scaling

**Cons**:
- Higher base cost
- Data transfer charges

### MirrorMaker 2 (Amazon MSK)

#### Monthly Costs (Estimate)
- **Primary MSK Cluster (3 × kafka.m5.large)**: ~$0.30/hour × 3 = ~$650/month
- **Secondary MSK Cluster (3 × kafka.m5.large)**: ~$650/month
- **MSK Connect Worker**: ~$0.10/hour × 2 = ~$150/month
- **EBS Storage (100GB × 6 brokers)**: ~$60/month
- **Data Transfer**: ~$0.09/GB × 2.5TB = ~$225/month
- **VPC**: ~$30/month
- **Total**: ~$1,765/month

**Pros**:
- More control over configuration
- Can optimize instance types
- Familiar AWS billing

**Cons**:
- Manual scaling and operations
- Additional monitoring setup required
- No built-in Schema Registry

### Cost Optimization Strategies

#### Cluster Linking
1. Use Basic clusters for dev/test ($0.70/hour vs $1.50/hour for Standard)
2. Enable compression (snappy/lz4) to reduce data transfer
3. Consider multi-tenant environments
4. Use topic filters to replicate only necessary topics

#### MirrorMaker 2
1. Right-size MSK instances (start with kafka.t3.small for dev)
2. Use single-AZ for non-production
3. Implement topic filtering aggressively
4. Consider Graviton instances for 20% cost savings
5. Use lifecycle policies for CloudWatch logs

## Operational Complexity

### Cluster Linking

#### Setup Complexity: ⭐⭐ (Low)
- Terraform configuration: ~200 lines
- 3-4 main resources (environments, clusters, link, mirror topics)
- Managed service handles upgrades

#### Ongoing Operations: ⭐ (Very Low)
- Monitor via Confluent Cloud UI
- Built-in metrics and alerting
- No patching or scaling needed

#### Failover Complexity: ⭐⭐ (Low)
1. Promote mirror topic (1 API call)
2. Update client bootstrap servers (SSM parameter)
3. Restart clients

**Automation**: Fully scriptable

### MirrorMaker 2

#### Setup Complexity: ⭐⭐⭐⭐ (High)
- Terraform configuration: ~500 lines
- 15+ resources (MSK clusters, connect, IAM, VPC, etc.)
- Connector JAR management
- Manual Schema Registry setup

#### Ongoing Operations: ⭐⭐⭐⭐ (High)
- Monitor MSK cluster health
- Monitor Connect worker health
- Manual capacity planning
- Patching and upgrades
- Connector state management

#### Failover Complexity: ⭐⭐⭐⭐ (High)
1. Stop MirrorMaker 2 connector
2. Identify last replicated offset
3. Translate consumer group offsets (manual or via checkpoints)
4. Update client configs (including topic prefix)
5. Restart clients
6. Verify consumption resumes correctly

**Automation**: Partially scriptable, manual verification needed

## Failure Scenarios

### Scenario 1: Clean Failover (Planned Maintenance)

#### Cluster Linking
1. Verify mirror lag is near-zero
2. Stop producers on primary
3. Wait for replication to catch up (< 1 minute)
4. Promote mirror topic
5. Repoint clients to secondary
6. Resume production

**RPO**: 0 messages  
**RTO**: < 2 minutes

#### MirrorMaker 2
1. Verify replication lag
2. Stop producers on primary
3. Wait for MM2 to catch up (1-5 minutes)
4. Stop MM2 connector
5. Translate consumer offsets
6. Repoint clients to secondary (with prefix)
7. Resume production

**RPO**: 0 messages  
**RTO**: 5-10 minutes

### Scenario 2: Sudden Primary Failure

#### Cluster Linking
1. Detect primary unavailability
2. Accept last replicated message as baseline
3. Promote mirror topic immediately
4. Repoint clients to secondary
5. Resume production

**RPO**: Last ~100 messages (mirror lag)  
**RTO**: 30-60 seconds

#### MirrorMaker 2
1. Detect primary unavailability
2. Stop MM2 connector (may be stuck)
3. Identify last checkpoint offset
4. Translate offsets from checkpoint topic
5. Manual verification of offset accuracy
6. Repoint clients to secondary
7. Resume production

**RPO**: Last ~1000 messages (replication lag + checkpoint lag)  
**RTO**: 2-5 minutes (includes manual verification)

## Recommendations

### Choose Cluster Linking When:
- ✅ Sub-second RPO is required
- ✅ Automated failover is critical
- ✅ Minimal operational overhead desired
- ✅ Consumer offset preservation is important
- ✅ Schema Registry sync is needed
- ✅ Budget allows for managed service

### Choose MirrorMaker 2 When:
- ✅ Already invested in Amazon MSK
- ✅ Need full control over infrastructure
- ✅ Can tolerate higher RPO/RTO
- ✅ Have Kafka operations expertise
- ✅ Cost optimization is top priority (at scale)
- ✅ Custom replication logic needed

## Testing Instructions

### 1. Deploy Both Solutions
```bash
# Cluster Linking (Confluent Cloud)
cd terraform/
terraform apply

# MirrorMaker 2 (MSK)
cd comparison/mirrormaker2/terraform/
terraform apply
```

### 2. Run Parallel Tests
```bash
# Test Cluster Linking
./scripts/run_drill.sh

# Test MirrorMaker 2
cd comparison/mirrormaker2/
./test_mm2_failover.sh
```

### 3. Collect Metrics
- Mirror/replication lag over time
- Failover execution time
- Message loss count
- Operational incidents

### 4. Analyze Results
```bash
./scripts/measure_rpo_rto.py --output json > cluster_linking_results.json
cd comparison/mirrormaker2/
./measure_mm2_rpo_rto.py --output json > mm2_results.json

# Compare
python3 -c "
import json
cl = json.load(open('cluster_linking_results.json'))
mm2 = json.load(open('mm2_results.json'))
print(f'Cluster Linking RTO: {cl[\"rto_seconds\"]}s')
print(f'MirrorMaker 2 RTO: {mm2[\"rto_seconds\"]}s')
"
```

## Conclusion

**Cluster Linking** offers superior performance, simpler operations, and faster recovery at a higher price point. It is the **recommended solution** for production environments where data durability and recovery speed are critical.

**MirrorMaker 2** is a viable alternative for organizations already invested in Amazon MSK, with experienced Kafka operators, or with budget constraints. However, it requires significantly more operational effort and offers lower guarantees for RPO/RTO.

For this demonstration project, **Cluster Linking is the primary implementation** with MirrorMaker 2 provided as a reference architecture for comparison purposes.
