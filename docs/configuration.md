# OpenSAS Configuration Reference

Complete reference for every key in `opensas.yaml`.

## Schema

The JSON Schema is at `config/schema.json` (Draft-07). Validate any config with:

```bash
python3 scripts/parse-config.py <config.yaml> --validate-only
```

---

## Top-level keys

| Key | Required | Type | Description |
|-----|----------|------|-------------|
| `stack` | yes | object | Stack identity — name and domain |
| `mesh` | yes | object | Layer 0 — mesh networking provider |
| `nodes` | yes | array | The VPS fleet — at least one control-plane node |
| `inference` | yes | object | Layer 1 — inference engine and models |
| `routing` | no | object | Layer 1 — API gateway config |
| `secrets` | yes | object | Layer 1 — secrets management |
| `storage` | yes | object | Layer 2 — S3-compatible storage |
| `observability` | yes | object | Layer 1 — tracing, metrics, dashboards |
| `orchestration` | no | object | Layer 3 — n8n and MCP servers |
| `interfaces` | no | object | Layer 4 — user-facing apps |

---

## `stack`

```yaml
stack:
  name: opensas-dev          # Required. Pattern: ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$
  domain: opensas.local      # Required. Base domain for all services.
```

Used for resource naming and TLS cert generation.

---

## `mesh`

```yaml
mesh:
  provider: headscale        # "headscale" (default) or "teleport"
```

| Value | Description |
|-------|-------------|
| `headscale` | Open-source Tailscale-compatible control server. Good for small-to-medium fleets. |
| `teleport` | Enterprise-grade with session recording, RBAC, and audit logging. Upgrade path. |

---

## `nodes`

```yaml
nodes:
  - name: control-1          # Required. Unique hostname.
    ip: 10.42.0.1            # Required. IPv4 address.
    roles:                   # Required. Non-empty, unique list.
      - control-plane        # At least one across the fleet.
      - storage              # Co-locate MinIO.
    # gpu block required if "gpu" is in roles
  - name: gpu-1
    ip: 10.42.0.2
    roles:
      - gpu
    gpu:
      vendor: nvidia         # Required if gpu role. "nvidia" | "amd" | "intel"
      count: 1               # Required if gpu role. Integer ≥ 1.
  - name: worker-1
    ip: 10.42.0.3
    roles:
      - worker               # General-purpose workloads
```

| Role | Description |
|------|-------------|
| `control-plane` | Runs K8s control plane, mesh server, management services. Required: ≥ 1 per fleet. |
| `gpu` | GPU-accelerated inference workloads. Requires `gpu` block. |
| `storage` | Runs MinIO or other stateful storage. |
| `worker` | General-purpose workloads (n8n, LibreChat, Streamlit, bots). |

---

## `inference`

```yaml
inference:
  engine: vllm               # "vllm" or "tgi"
  models:                    # Required. At least one model.
    - name: Qwen/Qwen2.5-7B-Instruct    # HuggingFace model ID
      quantization: null     # null (full precision) | "gptq" | "awq"
    - name: Qwen/Qwen2.5-32B-Instruct
      quantization: gptq
```

| Engine | Description |
|--------|-------------|
| `vllm` | High-throughput inference. Default. Supports PagedAttention, continuous batching. |
| `tgi` | HuggingFace Text Generation Inference. Alternative for HF-native deployments. |

---

## `routing`

```yaml
routing:
  litellm:
    rate_limit_tokens_per_min: 10000   # Integer ≥ 1. Global rate limit.
```

LiteLLM proxy handles load balancing, rate limiting, and cost tracking across model backends.

---

## `secrets`

```yaml
secrets:
  provider: openbao          # "openbao" (default) | "vault" | "external"
```

| Provider | Description |
|----------|-------------|
| `openbao` | Self-hosted Vault-compatible secrets store. Default for new deployments. |
| `vault` | Connect to an existing HashiCorp Vault instance. |
| `external` | Bring your own secrets management. Secrets injected via ExternalSecret or manual config. |

---

## `storage`

```yaml
storage:
  provider: minio            # Currently only "minio"
  buckets:                   # Required. At least one bucket.
    - name: documents        # Required. Pattern: ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$
      quota_gb: 100          # Optional. Soft quota in GB.
    - name: models-cache     # Shared model weights. vLLM loads from here.
    - name: n8n-workflows
    - name: app-data
```

Standard buckets:
- `documents` — Document storage for RAG pipelines
- `models-cache` — Shared model weights cache (RWX PVC or MinIO-backed)
- `n8n-workflows` — n8n workflow and credential backups
- `app-data` — General application data

---

## `observability`

```yaml
observability:
  tracing: langfuse          # "langfuse" or "phoenix"
  metrics: prometheus        # Default: "prometheus"
  dashboards: grafana        # Default: "grafana"
```

| Key | Options | Description |
|-----|---------|-------------|
| `tracing` | `langfuse`, `phoenix` | LLM call tracing — prompt chains, token usage, latency |
| `metrics` | `prometheus` | Cluster and inference metrics collection |
| `dashboards` | `grafana` | Pre-built dashboards for GPU, inference, cluster health |

---

## `orchestration`

```yaml
orchestration:
  n8n:
    enabled: true            # Default: true
    storage_gb: 10           # Default: 10. Persistent storage for workflows.
  mcp_servers:               # Optional. MCP tools exposed to agents.
    - name: filesystem       # Required. Unique name.
      type: stdio            # Required. "stdio" | "sse" | "streamable-http"
      mounts:                # Optional. Filesystem paths (for filesystem type).
        - /data
    - name: postgres-tools
      type: streamable-http
    - name: web-search
      type: sse
```

### n8n

Self-hosted visual workflow automation. Requires ~2 GB RAM minimum.
Connects to internal LiteLLM endpoint for AI workflow nodes.

### MCP servers

Model Context Protocol servers expose tools and data sources to LLM agents.
Each server runs as a K8s deployment with a ClusterIP service.

| Type | Description |
|------|-------------|
| `stdio` | Standard I/O transport. Server runs as a subprocess. |
| `sse` | Server-Sent Events transport. HTTP-based streaming. |
| `streamable-http` | HTTP transport with streaming support. |

---

## `interfaces`

```yaml
interfaces:
  librechat:
    enabled: true            # Default: true. Deploy LibreChat.
  streamlit_apps:            # Optional. Custom Streamlit apps.
    - name: llm-s3-demo      # Required. Unique name.
      repo: ./examples/streamlit/llm-s3-demo  # Required. Local path or URL.
  bots: []                   # Bot integrations (Telegram, Slack, etc.). TBD.
```

### LibreChat

Primary multi-model enterprise chat interface. ChatGPT-like UI.
Configured to use the internal LiteLLM endpoint — no external API keys needed.

### Streamlit apps

Lightweight, purpose-built frontends deployed alongside the stack.
Each app gets its own K8s deployment and service.

### Bots

ChatOps integrations (Telegram, Slack, Discord, Mattermost).
Deferred to later phases.

---

## Example: Full production config

See `config/opensas.sample.yaml` for a fully documented multi-node production configuration.

## Example: Minimal dev config

```yaml
stack:
  name: opensas-dev
  domain: opensas.local

mesh:
  provider: headscale

nodes:
  - name: my-machine
    ip: 127.0.0.1
    roles: [control-plane, storage, gpu]
    gpu:
      vendor: nvidia
      count: 1

inference:
  engine: vllm
  models:
    - name: Qwen/Qwen2.5-7B-Instruct

secrets:
  provider: openbao

storage:
  provider: minio
  buckets:
    - name: documents
    - name: models-cache

observability:
  tracing: langfuse
```

Minimum viable config: 10 top-level keys, 1 node, 1 model.
