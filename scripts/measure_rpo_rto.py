#!/usr/bin/env python3
"""
RPO/RTO Measurement Script

Calculates Recovery Point Objective (RPO) and Recovery Time Objective (RTO)
based on sequence numbers in DynamoDB and failover timestamps.

RPO: Number of messages lost during failover (sequence gaps)
RTO: Time taken to restore service (failover completion - failover start)
"""

import os
import json
import argparse
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import boto3
from botocore.exceptions import ClientError


def parse_timestamp(ts_str: str) -> datetime:
    """Parse ISO timestamp string"""
    return datetime.strptime(ts_str.replace("Z", "+00:00"), "%Y-%m-%dT%H:%M:%S.%f%z")


def read_timestamp_file(filepath: str) -> Optional[datetime]:
    """Read timestamp from file"""
    try:
        with open(filepath, "r") as f:
            ts_str = f.read().strip()
            return parse_timestamp(ts_str)
    except FileNotFoundError:
        print(f"Warning: Timestamp file not found: {filepath}")
        return None
    except Exception as e:
        print(f"Error reading timestamp file {filepath}: {e}")
        return None


def calculate_rto(start_file: str, end_file: str) -> Optional[float]:
    """Calculate RTO in seconds"""
    start_ts = read_timestamp_file(start_file)
    end_ts = read_timestamp_file(end_file)

    if not start_ts or not end_ts:
        return None

    delta = end_ts - start_ts
    return delta.total_seconds()


def scan_dynamodb_sequences(
    table_name: str,
    region: str,
    time_window_start: Optional[datetime] = None,
    time_window_end: Optional[datetime] = None,
) -> Dict[str, List[int]]:
    """
    Scan DynamoDB table and extract sequence numbers per order_id
    Returns dict mapping order_id to sorted list of sequence numbers
    """
    try:
        dynamodb = boto3.client("dynamodb", region_name=region)

        sequences = {}
        last_evaluated_key = None

        print(f"Scanning DynamoDB table: {table_name}")

        while True:
            scan_kwargs = {
                "TableName": table_name,
                "ProjectionExpression": "order_id, sequence_number, #ts",
                "ExpressionAttributeNames": {"#ts": "timestamp"},
            }

            if last_evaluated_key:
                scan_kwargs["ExclusiveStartKey"] = last_evaluated_key

            response = dynamodb.scan(**scan_kwargs)

            for item in response.get("Items", []):
                order_id = item["order_id"]["S"]
                seq_num = int(item["sequence_number"]["N"])
                timestamp = int(item["timestamp"]["N"])

                # Filter by time window if specified
                if time_window_start or time_window_end:
                    item_time = datetime.fromtimestamp(timestamp / 1000.0)
                    if time_window_start and item_time < time_window_start:
                        continue
                    if time_window_end and item_time > time_window_end:
                        continue

                if order_id not in sequences:
                    sequences[order_id] = []
                sequences[order_id].append(seq_num)

            last_evaluated_key = response.get("LastEvaluatedKey")
            if not last_evaluated_key:
                break

            print(f"  Scanned {len(sequences)} unique order IDs so far...")

        # Sort sequences for each order
        for order_id in sequences:
            sequences[order_id].sort()

        print(f"Scan complete: {len(sequences)} unique order IDs")
        return sequences

    except ClientError as e:
        print(f"Error scanning DynamoDB: {e.response['Error']['Message']}")
        return {}
    except Exception as e:
        print(f"Error scanning DynamoDB: {e}")
        return {}


def detect_sequence_gaps(
    sequences: Dict[str, List[int]],
) -> Tuple[int, int, List[Dict]]:
    """
    Detect gaps in sequence numbers
    Returns: (total_gaps, total_lost_messages, gap_details)
    """
    total_gaps = 0
    total_lost = 0
    gap_details = []

    for order_id, seq_list in sequences.items():
        if len(seq_list) < 2:
            continue

        for i in range(1, len(seq_list)):
            expected = seq_list[i - 1] + 1
            actual = seq_list[i]

            if actual != expected:
                gap_size = actual - expected
                total_gaps += 1
                total_lost += gap_size

                gap_details.append(
                    {
                        "order_id": order_id,
                        "expected_sequence": expected,
                        "actual_sequence": actual,
                        "gap_size": gap_size,
                    }
                )

    return total_gaps, total_lost, gap_details


def detect_duplicates(sequences: Dict[str, List[int]]) -> Tuple[int, List[Dict]]:
    """
    Detect duplicate sequence numbers
    Returns: (total_duplicates, duplicate_details)
    """
    total_duplicates = 0
    duplicate_details = []

    for order_id, seq_list in sequences.items():
        seen = set()
        for seq in seq_list:
            if seq in seen:
                total_duplicates += 1
                duplicate_details.append({"order_id": order_id, "sequence_number": seq})
            seen.add(seq)

    return total_duplicates, duplicate_details


def generate_report(
    rto_seconds: Optional[float],
    total_gaps: int,
    total_lost: int,
    total_duplicates: int,
    gap_details: List[Dict],
    duplicate_details: List[Dict],
    output_format: str = "text",
) -> str:
    """Generate measurement report"""

    if output_format == "json":
        report = {
            "rto_seconds": rto_seconds,
            "rto_human": f"{rto_seconds:.2f}s" if rto_seconds else "N/A",
            "rpo": {
                "total_gaps": total_gaps,
                "total_messages_lost": total_lost,
                "gap_details": gap_details[:10],  # Limit to first 10
            },
            "duplicates": {
                "total_duplicates": total_duplicates,
                "duplicate_details": duplicate_details[:10],
            },
        }
        return json.dumps(report, indent=2)

    else:  # text format
        lines = [
            "=" * 60,
            "DISASTER RECOVERY METRICS",
            "=" * 60,
            "",
            "Recovery Time Objective (RTO):",
            (
                f"  {rto_seconds:.2f} seconds"
                if rto_seconds
                else "  N/A (timestamp files not found)"
            ),
            "",
            "Recovery Point Objective (RPO):",
            f"  Total sequence gaps: {total_gaps}",
            f"  Total messages lost: {total_lost}",
            "",
            "Data Quality:",
            f"  Duplicate messages: {total_duplicates}",
            "",
        ]

        if gap_details:
            lines.append("Sample Message Gaps (first 10):")
            for gap in gap_details[:10]:
                lines.append(
                    f"  {gap['order_id']}: expected seq {gap['expected_sequence']}, "
                    f"got {gap['actual_sequence']} (gap: {gap['gap_size']})"
                )
            lines.append("")

        if duplicate_details:
            lines.append("Sample Duplicates (first 10):")
            for dup in duplicate_details[:10]:
                lines.append(
                    f"  {dup['order_id']}: duplicate seq {dup['sequence_number']}"
                )
            lines.append("")

        lines.append("=" * 60)

        return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Measure RPO and RTO for disaster recovery failover"
    )
    parser.add_argument(
        "--table-name",
        default=os.getenv("DYNAMODB_TABLE", "kafka-dr-demo-orders"),
        help="DynamoDB table name",
    )
    parser.add_argument(
        "--region", default=os.getenv("AWS_REGION", "us-east-1"), help="AWS region"
    )
    parser.add_argument(
        "--failover-start-file",
        default="/tmp/failover-start.timestamp",
        help="Failover start timestamp file",
    )
    parser.add_argument(
        "--failover-end-file",
        default="/tmp/failover-end.timestamp",
        help="Failover end timestamp file",
    )
    parser.add_argument(
        "--output", choices=["text", "json"], default="text", help="Output format"
    )
    parser.add_argument("--output-file", help="Output file (default: stdout)")

    args = parser.parse_args()

    # Calculate RTO
    print("Calculating RTO...")
    rto_seconds = calculate_rto(args.failover_start_file, args.failover_end_file)

    # Scan DynamoDB for sequences
    sequences = scan_dynamodb_sequences(args.table_name, args.region)

    if not sequences:
        print("Warning: No data found in DynamoDB table")
        total_gaps = 0
        total_lost = 0
        gap_details = []
        total_duplicates = 0
        duplicate_details = []
    else:
        # Detect gaps and duplicates
        print("Analyzing sequence numbers...")
        total_gaps, total_lost, gap_details = detect_sequence_gaps(sequences)
        total_duplicates, duplicate_details = detect_duplicates(sequences)

    # Generate report
    report = generate_report(
        rto_seconds,
        total_gaps,
        total_lost,
        total_duplicates,
        gap_details,
        duplicate_details,
        args.output,
    )

    # Output report
    if args.output_file:
        with open(args.output_file, "w") as f:
            f.write(report)
        print(f"\nReport saved to {args.output_file}")
    else:
        print("\n" + report)


if __name__ == "__main__":
    main()
