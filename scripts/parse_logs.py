#!/usr/bin/env python3
"""
parse_logs.py - Parse NOC transaction logs (CSV/JSON) for analysis.

Usage:
    python parse_logs.py --csv ../logs/noc_txn_log.csv --summary
    python parse_logs.py --json ../logs/noc_txn_log.json --latency-histogram
    python parse_logs.py --csv log.csv --filter "master=0" --output filtered.csv
    python parse_logs.py --csv log.csv --perf-report
"""

import csv
import json
import sys
import argparse
from collections import defaultdict


def parse_addr(s):
    """Parse hex address from log format '0xHHHH'."""
    if isinstance(s, str) and s.startswith("0x"):
        return int(s, 16)
    return int(s) if s else 0


def load_csv(path):
    """Load CSV transaction log."""
    records = []
    with open(path, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            records.append(row)
    return records


def load_json(path):
    """Load JSON transaction log."""
    with open(path, 'r') as f:
        data = json.load(f)
    return data.get("transactions", [])


def summarize(records):
    """Print summary statistics."""
    if not records:
        print("No records found.")
        return

    total = len(records)
    reads = sum(1 for r if r.get("direction") == "READ")
    writes = total - reads

    latencies = []
    errors = 0
    slaves = defaultdict(int)
    masters = defaultdict(int)
    protocols = defaultdict(int)

    for r in records:
        lat = r.get("latency", 0)
        if lat:
            latencies.append(float(lat))
        resp = r.get("resp", "OKAY")
        if resp not in ("OKAY", "0"):
            errors += 1
        slaves[r.get("slave_name", "unknown")] += 1
        masters[r.get("master", "unknown")] += 1
        protocols[r.get("protocol", "unknown")] += 1

    print(f"=== Transaction Log Summary ===")
    print(f"Total: {total}  (Read: {reads}  Write: {writes})")
    print(f"Errors: {errors}")
    if latencies:
        print(f"Latency - Min: {min(latencies):.2f}  Max: {max(latencies):.2f}  Avg: {sum(latencies)/len(latencies):.2f}")
    print(f"\nPer Slave:")
    for name, count in sorted(slaves.items(), key=lambda x: -x[1]):
        print(f"  {name:<20} {count:>6}")
    print(f"\nPer Master:")
    for name, count in sorted(masters.items(), key=lambda x: -x[1]):
        print(f"  Master {name:<16} {count:>6}")
    print(f"\nPer Protocol:")
    for name, count in sorted(protocols.items(), key=lambda x: -x[1]):
        print(f"  {name:<20} {count:>6}")


def latency_histogram(records):
    """Print latency distribution histogram."""
    latencies = [float(r.get("latency", 0)) for r in records if r.get("latency")]
    if not latencies:
        print("No latency data.")
        return

    max_lat = max(latencies)
    bins = 10
    bin_width = max_lat / bins if max_lat > 0 else 1
    hist = [0] * (bins + 1)

    for l in latencies:
        idx = min(int(l / bin_width), bins)
        hist[idx] += 1

    print(f"Latency Histogram (max={max_lat:.0f}, bins={bins}):")
    max_count = max(hist)
    for i, count in enumerate(hist):
        low = i * bin_width
        bar_len = int(50 * count / max_count) if max_count > 0 else 0
        print(f"  [{low:>8.0f}] {'#' * bar_len} {count}")


def perf_report(records):
    """Generate performance report from transaction logs."""
    if not records:
        return

    total_bytes = 0
    latencies = []

    for r in records:
        lat = r.get("latency", 0)
        if lat:
            latencies.append(float(lat))
        size = int(r.get("size", 2))
        length = int(r.get("len", 0))
        total_bytes += (length + 1) * (2 ** size)

    print(f"=== Performance Report ===")
    print(f"Total Transactions: {len(records)}")
    print(f"Total Bytes:        {total_bytes} ({total_bytes/1024:.0f} KB / {total_bytes/1024/1024:.2f} MB)")
    if latencies:
        avg_lat = sum(latencies) / len(latencies)
        print(f"Average Latency:    {avg_lat:.2f}")
        print(f"Min Latency:        {min(latencies):.2f}")
        print(f"Max Latency:        {max(latencies):.2f}")

    # Estimate throughput if timestamps available
    timestamps = [float(r.get("timestamp", 0)) for r in records if r.get("timestamp")]
    if len(timestamps) >= 2:
        duration = max(timestamps) - min(timestamps)
        if duration > 0:
            mbps = (total_bytes * 8 / 1000000) / (duration / 1e9)
            print(f"Duration:           {duration:.0f}")
            print(f"Throughput:         {mbps:.2f} Mbps")


def filter_records(records, filters):
    """Apply filters to records."""
    filtered = []
    for r in records:
        match = True
        for f in filters:
            key, val = f.split("=", 1)
            if key in r and str(r[key]) != val:
                match = False
                break
        if match:
            filtered.append(r)
    return filtered


def main():
    parser = argparse.ArgumentParser(description="Parse NOC transaction logs")
    parser.add_argument("--csv", help="CSV log file")
    parser.add_argument("--json", help="JSON log file")
    parser.add_argument("--summary", action="store_true", help="Print summary")
    parser.add_argument("--latency-histogram", action="store_true", help="Print latency histogram")
    parser.add_argument("--perf-report", action="store_true", help="Print performance report")
    parser.add_argument("--filter", action="append", help="Filter: key=value (repeatable)")
    parser.add_argument("--output", help="Output filtered CSV")
    args = parser.parse_args()

    if not args.csv and not args.json:
        parser.print_help()
        return 1

    if args.csv:
        records = load_csv(args.csv)
    elif args.json:
        records = load_json(args.json)

    if args.filter:
        records = filter_records(records, args.filter)
        print(f"Filtered: {len(records)} records")

    if args.output:
        if records and args.csv:
            with open(args.output, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=records[0].keys())
                writer.writeheader()
                writer.writerows(records)
            print(f"Written: {args.output}")

    if args.summary:
        summarize(records)
    if args.latency_histogram:
        latency_histogram(records)
    if args.perf_report:
        perf_report(records)

    if not any([args.summary, args.latency_histogram, args.perf_report, args.output]):
        summarize(records)

    return 0


if __name__ == "__main__":
    sys.exit(main())
