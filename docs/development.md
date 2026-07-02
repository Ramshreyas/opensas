# OpenSAS Development Guide

How to set up a local development environment for the Sovereign Automation Stack.

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| k3s | latest stable | Lightweight Kubernetes for local dev |
| kubectl | (bundled with k3s) | Cluster interaction |
| Helm | ≥ 3.16 | Package management for K8s |
| Ansible | ≥ 2.16 | Configuration management and playbooks |
| yamllint | ≥ 1.35 | YAML validation |
| Python 3 | ≥ 3.10 | Config parsing and scripting |
| nvidia-container-toolkit | ≥ 1.17 | GPU access from containers (if using GPU nodes) |

## Quickstart

```bash
# 1. Install toolchain
./scripts/bootstrap.sh

# 2. Configure your hardware
cp config/opensas.sample.yaml config/opensas.dev.yaml
# Edit config/opensas.dev.yaml — set your node names, IPs, GPU config

# 3. Validate config
python3 scripts/parse-config.py config/opensas.dev.yaml --validate-only

# 4. Generate Ansible inventory
python3 scripts/parse-config.py config/opensas.dev.yaml --output-inventory --output-vars

# 5. Run smoke test
ansible-playbook -i inventory/opensas-dev/hosts.yml -c local playbooks/smoke-test.yml
```

## Local K8s Setup (k3s)

### Single-node cluster

The default dev setup runs k3s as a single-node cluster with the GPU attached:

```bash
# Install k3s server
sudo ./scripts/install-k3s-server.sh

# Configure GPU support
sudo ./scripts/setup-gpu-k3s.sh

# Verify
kubectl get nodes
kubectl describe node $(hostname) | grep nvidia.com/gpu
# Should show: nvidia.com/gpu: 1

# Smoke test
kubectl run gpu-test --image=nvidia/cuda:12.4.0-runtime-ubuntu22.04 \
  --restart=Never --overrides='{"spec":{"runtimeClassName":"nvidia","nodeName":"'$(hostname)'"}}' \
  --command -- nvidia-smi
kubectl logs gpu-test
kubectl delete pod gpu-test
```

### Multi-node cluster

To add a GPU worker node (e.g., DGX Spark):

1. Install k3s server on the control-plane node (above)
2. Copy the join command printed by `install-k3s-server.sh`
3. Run on the worker node:
   ```bash
   curl -sfL https://get.k3s.io | K3S_URL=https://<server-ip>:6443 \
     K3S_TOKEN=<token> sh -
   ```
4. Run `setup-gpu-k3s.sh` on the worker node

## Configuration

### opensas.dev.yaml

A minimal single-node config:

```yaml
stack:
  name: opensas-dev
  domain: opensas.local

mesh:
  provider: headscale

nodes:
  - name: <your-hostname>
    ip: 127.0.0.1
    roles:
      - control-plane
      - storage
      - gpu
    gpu:
      vendor: nvidia      # nvidia | amd | intel
      count: 1            # number of GPUs on this node

inference:
  engine: vllm
  models:
    - name: Qwen/Qwen2.5-7B-Instruct
      quantization: null

routing:
  litellm:
    rate_limit_tokens_per_min: 10000

secrets:
  provider: openbao

storage:
  provider: minio
  buckets:
    - name: documents
    - name: models-cache

observability:
  tracing: langfuse
  metrics: prometheus
  dashboards: grafana

orchestration:
  n8n:
    enabled: true
    storage_gb: 10

interfaces:
  librechat:
    enabled: true
```

### Validation workflow

```bash
# YAML linting + Helm lint
./scripts/validate.sh

# Config schema validation
python3 scripts/parse-config.py config/opensas.dev.yaml --validate-only

# Generate inventory (for ansible playbooks)
python3 scripts/parse-config.py config/opensas.dev.yaml --output-inventory

# Full smoke test
ansible-playbook -i inventory/opensas-dev/hosts.yml playbooks/smoke-test.yml
```

## Project Structure

```
opensas/
├── AGENTS.md              # Pi coding conventions
├── ROADMAP.md             # Development roadmap
├── opensas.md             # Architecture one-pager
│
├── config/
│   ├── schema.json        # JSON Schema for opensas.yaml
│   ├── opensas.sample.yaml  # Fully documented sample
│   └── opensas.dev.yaml   # Your local dev config
│
├── scripts/
│   ├── bootstrap.sh       # Install toolchain
│   ├── validate.sh        # Run all lints
│   ├── parse-config.py    # Config validation + inventory generation
│   ├── install-k3s-server.sh  # k3s server setup
│   └── setup-gpu-k3s.sh   # GPU configuration for k3s
│
├── playbooks/
│   └── smoke-test.yml     # System info + GPU check
│
├── charts/                # Helm charts (per layer)
├── inventory/             # Generated Ansible inventory
├── docs/                  # Documentation
└── examples/              # Sample workflows and apps
```

## Troubleshooting

### k3s node not Ready
```bash
sudo systemctl status k3s
sudo journalctl -u k3s -n 50 --no-pager
```

### GPU not showing in `nvidia.com/gpu`
```bash
# Check device plugin
kubectl get pods -n kube-system | grep nvidia

# Check device plugin logs
kubectl logs -n kube-system -l name=nvidia-device-plugin-ds

# Verify nvidia-container-toolkit
nvidia-container-toolkit --version

# Restart k3s after containerd config changes
sudo systemctl restart k3s
```

### `nvidia-smi` works on host but not in containers
Ensure the nvidia runtime is in containerd config:
```bash
sudo cat /var/lib/rancher/k3s/agent/etc/containerd/config.toml | grep -A5 nvidia
```
Should show `runtime_type = "io.containerd.runc.v2"` with nvidia options.

### Config validation fails
```bash
# Get detailed schema validation (install jsonschema first)
pip3 install jsonschema
python3 scripts/parse-config.py config/opensas.dev.yaml --validate-only
```

### Ansible playbook connection refused
Use `-c local` for single-node dev, or ensure SSH is configured for remote nodes.
