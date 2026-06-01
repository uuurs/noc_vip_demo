#!/usr/bin/env python3
"""
gen_slave_config.py - Helper script to generate/manage NOC slave configurations.

Usage:
    python gen_slave_config.py --template > noc_slave_config.json
    python gen_slave_config.py --validate config.json
    python gen_slave_config.py --summary config.json
"""

import json
import sys
import argparse


def generate_template(output):
    """Generate a template slave configuration JSON file."""
    template = {
        "noc_config": {
            "name": "my_noc",
            "version": "1.0",
            "description": "Template NOC configuration",
            "num_masters": 2,
            "data_width": 64,
            "addr_width": 40,
            "clk_period_ps": 1000
        },
        "slaves": [
            {
                "name": "example_slave",
                "base_addr": "0xA0000000",
                "addr_range": "0x00010000",
                "supported_protocols": ["AXI4"],
                "supported_burst": ["FIXED", "INCR", "WRAP"],
                "max_len": 15,
                "max_size": 7,
                "outstanding_capability": 16,
                "alignment_required": True,
                "interleaving_supported": True,
                "write_enable": True,
                "read_latency_min": 0,
                "read_latency_max": 16,
                "write_latency_min": 0,
                "write_latency_max": 16,
                "special_regions": []
            }
        ],
        "masters": [
            {"name": "cpu", "id": 0, "protocol": "AXI4", "thread_id_width": 4, "active": True}
        ],
        "access_matrix": {
            "cpu": ["example_slave"]
        }
    }
    json.dump(template, output, indent=2)
    output.write('\n')


def validate_config(config):
    """Validate NOC configuration for consistency."""
    errors = []
    warnings = []

    if "slaves" not in config or len(config["slaves"]) == 0:
        errors.append("No slaves configured")
    if "masters" not in config or len(config["masters"]) == 0:
        errors.append("No masters configured")

    valid_protos = {"AXI4", "AXI4Lite", "AHBLite", "APB4", "AvalonMM"}
    valid_bursts = {"FIXED", "INCR", "WRAP"}

    # Check each slave
    addresses = []
    for i, slave in enumerate(config.get("slaves", [])):
        name = slave.get("name", f"slave[{i}]")
        base = int(slave.get("base_addr", "0x0").replace("_", ""), 16)
        limit = int(slave.get("addr_range", "0x0").replace("_", ""), 16)

        if limit == 0:
            errors.append(f"Slave '{name}': addr_range is zero")
        if base % 4096 != 0 and slave.get("alignment_required", True):
            warnings.append(f"Slave '{name}': base_addr 0x{base:X} not 4KB aligned")

        # Check for overlapping addresses
        for addr_base, addr_limit, addr_name in addresses:
            if base < addr_base + addr_limit and addr_base < base + limit:
                errors.append(
                    f"Overlap: '{name}' [0x{base:X}-0x{base+limit-1:X}] "
                    f"overlaps '{addr_name}' [0x{addr_base:X}-0x{addr_base+addr_limit-1:X}]"
                )
        addresses.append((base, limit, name))

        # Validate protocol names
        for proto in slave.get("supported_protocols", []):
            if proto not in valid_protos:
                warnings.append(f"Slave '{name}': unknown protocol '{proto}'")

        # Validate burst types
        for burst in slave.get("supported_burst", []):
            if burst not in valid_bursts:
                warnings.append(f"Slave '{name}': unknown burst type '{burst}'")

        # Validate numerical limits
        if slave.get("max_len", 0) > 255:
            warnings.append(f"Slave '{name}': max_len {slave['max_len']} > 255 (AXI4 limit)")
        if slave.get("max_size", 0) > 7:
            errors.append(f"Slave '{name}': max_size {slave['max_size']} > 7")
        if slave.get("outstanding_capability", 0) < 0:
            errors.append(f"Slave '{name}': negative outstanding_capability")

    # Check masters
    master_names = set()
    for i, master in enumerate(config.get("masters", [])):
        name = master.get("name", f"master[{i}]")
        master_names.add(name)
        if master.get("protocol", "") not in valid_protos:
            warnings.append(f"Master '{name}': unknown protocol '{master.get('protocol', '')}'")

    # Check access matrix
    slave_names = {s["name"] for s in config.get("slaves", [])}
    access_matrix = config.get("access_matrix", {})
    if access_matrix:
        for mst_name, allowed_slaves in access_matrix.items():
            if mst_name not in master_names:
                warnings.append(f"Access matrix: master '{mst_name}' not in masters list")
            for slv_name in allowed_slaves:
                if slv_name not in slave_names:
                    errors.append(f"Access matrix: slave '{slv_name}' (referenced by '{mst_name}') not in slaves list")
    else:
        warnings.append("No access_matrix defined; all masters can access all slaves by default")

    return errors, warnings


def summary(config):
    """Print a readable summary of the NOC configuration."""
    nc = config.get("noc_config", {})
    print(f"NOC: {nc.get('name', 'unnamed')} v{nc.get('version', '?')}")
    print(f"  Masters: {nc.get('num_masters', 0)}  Data: {nc.get('data_width', 0)}b  Addr: {nc.get('addr_width', 0)}b")
    print(f"  Clock: {nc.get('clk_period_ps', 0)}ps")
    print()
    print(f"Slaves ({len(config.get('slaves', []))}):")
    print(f"  {'Name':<20} {'Base':<14} {'Range':<12} {'Protos':<20} {'Out.':<5} {'Bursts'}")
    print(f"  {'-'*20} {'-'*14} {'-'*12} {'-'*20} {'-'*5} {'-'*20}")
    for slv in config.get("slaves", []):
        base = int(slv["base_addr"].replace("_", ""), 16)
        rng = int(slv["addr_range"].replace("_", ""), 16)
        protos = ",".join(slv.get("supported_protocols", []))
        out = slv.get("outstanding_capability", "?")
        bursts = ",".join(slv.get("supported_burst", []))
        print(f"  {slv['name']:<20} 0x{base:<12X} 0x{rng:<10X} {protos:<20} {out:<5} {bursts}")
    print()
    print(f"Masters ({len(config.get('masters', []))}):")
    print(f"  {'Name':<20} {'ID':<4} {'Protocol':<12} {'ThreadID':<10}")
    print(f"  {'-'*20} {'-'*4} {'-'*12} {'-'*10}")
    for mst in config.get("masters", []):
        print(f"  {mst['name']:<20} {mst.get('id', '?'):<4} {mst.get('protocol', '?'):<12} {mst.get('thread_id_width', '?'):<10}")

    access_matrix = config.get("access_matrix", {})
    if access_matrix:
        print(f"\nAccess Matrix:")
        for mst_name, allowed in access_matrix.items():
            print(f"  {mst_name:<20} -> [{', '.join(allowed)}]")
    else:
        print(f"\nAccess Matrix: NOT DEFINED (all masters can access all slaves)")


def main():
    parser = argparse.ArgumentParser(description="NOC slave configuration helper")
    parser.add_argument("--template", action="store_true", help="Generate template JSON to stdout")
    parser.add_argument("--validate", metavar="FILE", help="Validate a config JSON file")
    parser.add_argument("--summary", metavar="FILE", help="Print config summary")
    args = parser.parse_args()

    if args.template:
        generate_template(sys.stdout)
    elif args.validate:
        with open(args.validate, 'r') as f:
            config = json.load(f)
        errors, warnings = validate_config(config)
        if errors:
            print("ERRORS:")
            for e in errors:
                print(f"  - {e}")
        if warnings:
            print("WARNINGS:")
            for w in warnings:
                print(f"  - {w}")
        if not errors and not warnings:
            print("Configuration is valid.")
        return 1 if errors else 0
    elif args.summary:
        with open(args.summary, 'r') as f:
            config = json.load(f)
        summary(config)
    else:
        parser.print_help()

    return 0


if __name__ == "__main__":
    sys.exit(main())
