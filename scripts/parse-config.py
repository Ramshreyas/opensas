#!/usr/bin/env python3
"""
parse-config.py — Validate and transform opensas.yaml configurations.

Usage:
  python3 scripts/parse-config.py config/opensas.dev.yaml --validate-only
  python3 scripts/parse-config.py config/opensas.dev.yaml --output-inventory
  python3 scripts/parse-config.py config/opensas.dev.yaml --output-vars

The script validates the given config against config/schema.json and can
emit Ansible-compatible inventory and vars files for downstream playbooks.
"""

import argparse
import json
import os
import sys
from pathlib import Path

import yaml

# Path to the JSON Schema, relative to the repo root
REPO_ROOT = Path(__file__).resolve().parent.parent
SCHEMA_PATH = REPO_ROOT / "config" / "schema.json"
DEFAULT_INVENTORY_DIR = REPO_ROOT / "inventory"


def load_yaml(path: Path) -> dict:
    """Load and parse a YAML file."""
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
        if data is None:
            print(f"Error: {path} is empty.", file=sys.stderr)
            sys.exit(1)
        return data
    except yaml.YAMLError as e:
        print(f"Error parsing {path}: {e}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: {path} not found.", file=sys.stderr)
        sys.exit(1)


def validate_config(config: dict, schema: dict) -> bool:
    """
    Validate config against JSON Schema.

    Uses jsonschema if available, otherwise falls back to basic structural checks.
    Returns True if valid, exits with code 1 if invalid.
    """
    try:
        import jsonschema
    except ImportError:
        print("Warning: jsonschema not installed. Running basic structural validation only.",
              file=sys.stderr)
        print("  Install it with: pip3 install jsonschema", file=sys.stderr)
        return _validate_basic(config, schema)

    validator = jsonschema.Draft7Validator(schema)
    errors = sorted(validator.iter_errors(config), key=lambda e: e.path)

    if errors:
        print(f"Validation failed with {len(errors)} error(s):", file=sys.stderr)
        for error in errors:
            path = ".".join(str(p) for p in error.path) if error.path else "(root)"
            print(f"  • {path}: {error.message}", file=sys.stderr)
        sys.exit(1)

    return True


def _validate_basic(config: dict, schema: dict) -> bool:
    """Basic structural validation without jsonschema."""
    required = schema.get("required", [])
    missing = [k for k in required if k not in config]
    if missing:
        print(f"Error: Missing required top-level keys: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)

    # Check nodes array
    if "nodes" in config:
        _check_nodes(config["nodes"], schema["properties"]["nodes"])

    print("Basic validation passed.", file=sys.stderr)
    return True


def _check_nodes(nodes: list, nodes_schema: dict) -> None:
    """Validate nodes array structure."""
    if not nodes:
        print("Error: nodes list is empty.", file=sys.stderr)
        sys.exit(1)

    has_control_plane = False
    for node in nodes:
        roles = node.get("roles", [])
        if "control-plane" in roles:
            has_control_plane = True
        if "gpu" in roles and "gpu" not in node:
            print(f"Error: Node '{node.get('name', 'unknown')}' has 'gpu' role but no gpu config.",
                  file=sys.stderr)
            sys.exit(1)

    if not has_control_plane:
        print("Error: At least one node must have the 'control-plane' role.", file=sys.stderr)
        sys.exit(1)


def generate_inventory(config: dict, output_dir: Path) -> Path:
    """
    Generate an Ansible inventory from the config.
    Returns the path to the generated hosts.yml.
    """
    stack_name = config["stack"]["name"]
    inventory_dir = output_dir / stack_name
    inventory_dir.mkdir(parents=True, exist_ok=True)

    nodes = config["nodes"]

    # Build inventory groups by role
    groups: dict[str, list[dict]] = {
        "control_plane": [],
        "gpu": [],
        "storage": [],
        "worker": [],
        "all": nodes,
    }

    for node in nodes:
        node_name = node["name"]
        host_entry = {
            "ansible_host": node["ip"],
            "ansible_user": "root",  # default; overridable via group_vars
        }

        if "gpu" in node.get("roles", []):
            host_entry["gpu_vendor"] = node["gpu"]["vendor"]
            host_entry["gpu_count"] = node["gpu"]["count"]

        if "control-plane" in node["roles"]:
            groups["control_plane"].append({node_name: host_entry})
        if "gpu" in node["roles"]:
            groups["gpu"].append({node_name: host_entry})
        if "storage" in node["roles"]:
            groups["storage"].append({node_name: host_entry})
        if "worker" in node["roles"]:
            groups["worker"].append({node_name: host_entry})

    # Also add nodes with 'all' host entries
    all_hosts = {}
    for node in nodes:
        host_entry = {
            "ansible_host": node["ip"],
            "ansible_user": "root",
        }
        all_hosts[node["name"]] = host_entry

    # Write inventory
    inventory = {"all": {"hosts": all_hosts}}

    for group_name, group_hosts in groups.items():
        if group_name == "all":
            continue
        if group_hosts:
            # Flatten list of single-key dicts into a hosts dict
            hosts = {}
            for entry in group_hosts:
                hosts.update(entry)
            inventory[group_name] = {"hosts": hosts}

    hosts_file = inventory_dir / "hosts.yml"
    with open(hosts_file, "w") as f:
        f.write("# Generated by parse-config.py — do not edit directly\n")
        f.write(f"# Source: opensas.yaml (stack: {stack_name})\n\n")
        yaml.dump(inventory, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f"Inventory written to: {hosts_file}")
    return hosts_file


def generate_vars(config: dict, output_dir: Path) -> Path:
    """
    Generate Ansible group vars and host vars from the config.
    Returns the path to the generated vars directory.
    """
    stack_name = config["stack"]["name"]
    vars_dir = output_dir / stack_name / "group_vars"
    vars_dir.mkdir(parents=True, exist_ok=True)

    # All-nodes vars
    all_vars = {
        "stack_name": config["stack"]["name"],
        "stack_domain": config["stack"]["domain"],
        "mesh_provider": config["mesh"]["provider"],
        "inference_engine": config["inference"]["engine"],
        "inference_models": config["inference"]["models"],
    }

    if "routing" in config:
        all_vars["litellm_config"] = config["routing"].get("litellm", {})

    all_vars["secrets_provider"] = config["secrets"]["provider"]
    all_vars["storage_provider"] = config["storage"]["provider"]
    all_vars["storage_buckets"] = config["storage"]["buckets"]
    all_vars["observability_tracing"] = config["observability"]["tracing"]
    all_vars["observability_metrics"] = config["observability"].get("metrics", "prometheus")
    all_vars["observability_dashboards"] = config["observability"].get("dashboards", "grafana")

    # Orchestration
    if "orchestration" in config:
        orch = config["orchestration"]
        all_vars["n8n_enabled"] = orch.get("n8n", {}).get("enabled", True)
        all_vars["n8n_storage_gb"] = orch.get("n8n", {}).get("storage_gb", 10)
        all_vars["mcp_servers"] = orch.get("mcp_servers", [])

    # Interfaces
    if "interfaces" in config:
        iface = config["interfaces"]
        all_vars["librechat_enabled"] = iface.get("librechat", {}).get("enabled", True)
        all_vars["streamlit_apps"] = iface.get("streamlit_apps", [])
        all_vars["bots"] = iface.get("bots", [])

    all_vars_file = vars_dir / "all.yml"
    with open(all_vars_file, "w") as f:
        f.write("# Generated by parse-config.py — do not edit directly\n")
        f.write("# Group vars for: all\n\n")
        yaml.dump(all_vars, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    # GPU node vars
    gpu_nodes = [n for n in config["nodes"] if "gpu" in n.get("roles", [])]
    if gpu_nodes:
        gpu_vars_dir = output_dir / stack_name / "host_vars"
        gpu_vars_dir.mkdir(parents=True, exist_ok=True)
        for node in gpu_nodes:
            gpu_vars = {
                "gpu_vendor": node["gpu"]["vendor"],
                "gpu_count": node["gpu"]["count"],
                "node_roles": node["roles"],
            }
            gpu_vars_file = gpu_vars_dir / f"{node['name']}.yml"
            with open(gpu_vars_file, "w") as f:
                f.write(f"# Generated by parse-config.py — do not edit directly\n")
                f.write(f"# Host vars for: {node['name']}\n\n")
                yaml.dump(gpu_vars, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

    print(f"Vars written to: {vars_dir} (and host_vars)")
    return vars_dir


def main():
    parser = argparse.ArgumentParser(
        description="Validate and transform OpenSAS configuration."
    )
    parser.add_argument(
        "config_file",
        type=Path,
        help="Path to the opensas.yaml configuration file.",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Validate the config against schema and exit.",
    )
    parser.add_argument(
        "--output-inventory",
        action="store_true",
        help="Generate Ansible inventory from the config.",
    )
    parser.add_argument(
        "--output-vars",
        action="store_true",
        help="Generate Ansible group vars from the config.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_INVENTORY_DIR,
        help=f"Directory for generated inventory/vars. Default: {DEFAULT_INVENTORY_DIR}",
    )

    args = parser.parse_args()

    # Default: if no flags, validate only
    if not args.validate_only and not args.output_inventory and not args.output_vars:
        args.validate_only = True

    # Load schema
    schema = load_yaml(SCHEMA_PATH)
    # Ensure schema is valid JSON (it's YAML-compatible, but load as dict)
    schema = json.loads(json.dumps(schema))

    # Load and validate config
    config = load_yaml(args.config_file)
    validate_config(config, schema)

    if args.validate_only:
        print(f"✓ {args.config_file} is valid.")
        return

    if args.output_inventory:
        generate_inventory(config, args.output_dir)

    if args.output_vars:
        generate_vars(config, args.output_dir)


if __name__ == "__main__":
    main()
