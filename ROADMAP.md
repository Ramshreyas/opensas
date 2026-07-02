# ROADMAP.md — OpenSAS Development Roadmap

> **How to use this file:** Each phase has numbered checkpoints. Check `- [ ]` boxes as completed.
> At every **Decision Gate**, pause and decide whether the plan still holds. This is the point
> where scope, sequencing, or architecture can change. Commit the updated ROADMAP.md to
> record the decision.

---

## Working Discipline

### Per-phase rules

1. **Start each phase in a fresh Pi session.** This keeps context manageable — load only
   the previous phase's documentation and the relevant config/schema files.
2. **Document on completion.** Every phase must produce or update its corresponding doc in
   `docs/` before the phase is marked complete. No phase is "done" until the doc is written.
3. **Commit at every checkpoint.** Each `- [x]` comes with a conventional commit referencing
   the checkpoint (`feat(config): implement schema for opensas.yaml — cp 0.2`).
4. **No hardware assumptions in the repo.** This roadmap mentions specific hardware (e.g.,
   "RTX 4090") only to describe *how we validate locally on the developer's machine today*.
   The repo itself must be hardware-agnostic. Config samples and playbooks must not hardcode
   GPU models, node counts, or IPs. Others will bring their own hardware.

### How to track progress

1. **This file** (`ROADMAP.md`) is the source of truth. Check boxes as checkpoints complete.
2. **GitHub Issues**: Create one issue per checkpoint, label `roadmap`, link from the `- [ ]` item.
3. **Commit messages**: Reference the checkpoint:
   ```
   feat(config): add JSON schema for opensas.yaml (closes cp 0.2)
   ```

### Changing plans

Every checkpoint ends with a **Decision Gate**. If circumstances change (new requirements,
blockers discovered, time constraints), the decision at any gate can redirect the roadmap.
When this happens:

1. Update the relevant checkpoint's Decision Gate with the new decision and rationale
2. Strike through deprecated checkpoints: `- [x] ~~Original plan~~` (don't delete — keep history)
3. Add new checkpoints below
4. Commit with message: `docs(roadmap): decision at gate X.Y — <summary>`

---

## Phase 0: Developer Sandbox & Config Schema

**Goal:** Establish the local dev loop, define the single `opensas.yaml` config schema, and validate
that we can parse config → generate Ansible inventory → lint/simulate a full deployment.

**Entry criteria:** Nothing. This is the starting point.

**Estimated duration:** 3–5 days

### Checkpoint 0.1 — Repository scaffolding

- [x] Create all directories from AGENTS.md checklist (`charts/`, `config/`, `docs/`, `examples/`, `scripts/`, `.github/workflows/`)
- [x] Create `.yamllint` config matching AGENTS.md conventions
- [x] Create `scripts/bootstrap.sh` — installs helm, k3s, ansible, yamllint
- [x] Create `scripts/validate.sh` — runs all lints (yamllint, helm lint)

**Validation:**
```bash
./scripts/bootstrap.sh   # installs toolchain cleanly
./scripts/validate.sh    # passes on empty scaffold (no errors on missing dirs)
```

**Decision gate (resolved):** Ansible ✓. Local K8s: **k3s** (not kind/k3d/minikube) — better match for the multi-node VPS fleet model and supports joining remote GPU workers directly.

---

### Checkpoint 0.2 — Config schema & sample

- [x] Define JSON Schema for `opensas.yaml` (in `config/schema.json`)
- [x] Create `config/opensas.sample.yaml` — a fully-documented sample config with all options
- [x] Create `config/opensas.dev.yaml` — a minimal config for local dev (k3s + local GPU node)
- [x] Write `scripts/parse-config.py` — validates a given `opensas.yaml` against schema, outputs resolved Ansible inventory + vars

**Sample `opensas.yaml` structure (to be formalized in schema):**
```yaml
stack:
  name: opensas-dev
  domain: opensas.local

mesh:
  provider: headscale       # headscale (default) | teleport (upgrade path for RBAC/audit)

nodes:                      # the VPS fleet (no hardware assumptions — user provides)
  - name: control-1
    ip: 10.42.0.1
    roles: [control-plane, storage]
  - name: gpu-1
    ip: 10.42.0.2
    roles: [gpu]
    gpu:
      vendor: nvidia        # nvidia | amd | intel
      count: 1
  # Add more GPU nodes here as needed. Architecture is vendor-agnostic.

inference:
  engine: vllm              # vllm | tgi
  models:                   # user provides their own model list
    - name: Qwen/Qwen2.5-7B-Instruct
      quantization: null    # null = full precision; gptq, awq for quantized

routing:
  litellm:
    rate_limit_tokens_per_min: 10000

secrets:
  provider: openbao         # openbao | vault | external

storage:
  provider: minio
  buckets:
    - name: documents
      quota_gb: 100
    - name: models-cache

observability:
  tracing: langfuse          # langfuse | phoenix
  metrics: prometheus
  dashboards: grafana

orchestration:
  n8n:
    enabled: true
    storage_gb: 10
  mcp_servers:
    - name: filesystem
      type: stdio
      mounts: [/data]

interfaces:
  librechat:
    enabled: true
  streamlit_apps:
    - name: llm-s3-demo
      repo: ./examples/streamlit/llm-s3-demo
  bots: []                   # telegram, slack, discord — TBD
```

**Validation:**
```bash
python3 scripts/parse-config.py config/opensas.dev.yaml --validate-only
python3 scripts/parse-config.py config/opensas.dev.yaml --output-inventory
ansible-inventory -i inventory/dev/hosts.yml --list  # valid Ansible inventory
```

**Decision gate (resolved):** Schema is sufficient for Phase 1. MCP servers stay stateless (deferred). Networking/ingress keys deferred to Phase 2.

---

### Checkpoint 0.3 — Local K8s cluster with GPU

- [x] Install k3s server on dev machine (yoneda) — 1 control-plane node (single-node for Phase 0)
- [x] ~~Join the local GPU machine as a GPU worker node~~ — GPU is on the same machine (RTX 4090); atom (DGX Spark) to be enrolled in Phase 1
- [x] Install NVIDIA device plugin on the cluster (scripts/setup-gpu-k3s.sh)
- [x] Verify GPU allocation: `kubectl describe node yoneda | grep nvidia.com/gpu` → 1 GPU allocatable
- [x] Run a smoke-test GPU pod: `nvidia-smi` inside a container → RTX 4090, 24564 MiB

> **Note for other developers:** This checkpoint is validated on the author's machine
> (which has an RTX 4090 and a separate inference device). The repo itself contains
> no hardware-specific configuration. Adapt node names, GPU counts, and IPs to your setup.

**Validation:**
```bash
kubectl get nodes          # shows control-plane + gpu worker(s)
kubectl run -it --rm gpu-test --image=nvidia/cuda:12.4.0-runtime-ubuntu22.04 \
  --restart=Never --overrides='{"spec":{"nodeName":"<your-gpu-node>"}}' -- nvidia-smi
# Should display available GPUs
```

**Decision gate (resolved):** Single-node colocation works well — yoneda (62 GB RAM, RTX 4090) runs both control-plane and GPU workloads. atom (DGX Spark) will join as GPU worker in Phase 1 when the mesh is ready.

---

### Checkpoint 0.4 — Ansible smoke test

- [x] Write a minimal Ansible playbook (`playbooks/smoke-test.yml`) that:
  - Takes the inventory generated by `parse-config.py`
  - Reports OS, kernel, available memory, disk
  - On GPU nodes: reports `nvidia-smi` output
- [x] Test against localhost (`ansible_connection=local`) — all 7 tasks OK, 0 failed

**Validation:**
```bash
ansible-playbook -i inventory/dev/hosts.yml playbooks/smoke-test.yml
# Green across all nodes. GPU nodes show available GPU information.
```

**Decision gate (resolved):** Path A — simulate mesh locally with Headscale + Tailscale in Docker. atom (DGX Spark) enrolled later. Proceed to Phase 1.

---

### Checkpoint 0.5 — Phase 0 documentation

- [x] Write `docs/development.md` — local dev setup guide:
  - Prerequisites (helm, kubectl, k3s, ansible, yamllint)
  - How to configure `opensas.dev.yaml` for your hardware
  - How to run each validation command
  - Troubleshooting common GPU/K8s issues
- [x] Write `docs/configuration.md` — reference for every `opensas.yaml` key, with examples

**Validation:**
```bash
# A new developer should be able to follow docs/development.md from scratch
# and reach a passing validate.sh run.
```

---

## Phase 1: Mesh Foundation (Layer 0)

**Goal:** Establish the zero-trust service mesh using Headscale (open-source Tailscale control
server) across all nodes. After this phase, every node communicates over encrypted WireGuard
tunnels managed by Headscale, reachable by a private Tailscale IP, and direct SSH key access
is replaced by Tailscale SSH.

**Entry criteria:** Phase 0 complete. Nodes accessible via SSH.

**Estimated duration:** 3–5 days

### Checkpoint 1.1 — Headscale control plane

- [x] Ansible playbook `playbooks/headscale.yml`:
  - Installs Headscale server on the control node
  - Configures Headscale with a persistent SQLite (or Postgres) backend
  - Exposes Headscale API on the WireGuard/Tailscale private IP only
- [x] Generate a pre-auth key for node enrollment

**Validation:**
```bash
ansible-playbook -i inventory/dev/hosts.yml playbooks/headscale.yml
curl http://10.42.0.1:8080/health   # Headscale health check (from within mesh)
```

**Decision gate:** Headscale on SQLite is fine for small fleets. If scaling beyond ~50 nodes,
switch to Postgres backend. **For now, SQLite is the default.**

---

### Checkpoint 1.2 — Node enrollment & mesh

- [x] Ansible playbook `playbooks/tailscale-enroll.yml`:
  - Installs Tailscale client on all non-control nodes
  - Enrolls each node with Headscale using pre-auth keys
  - Configures Tailscale SSH (replaces raw SSH key management)
  - Verifies each node is reachable by its Tailscale IP
- [x] Idempotent — re-running does not break existing enrollments

**Validation:**
```bash
ansible-playbook -i inventory/dev/hosts.yml playbooks/tailscale-enroll.yml
# From control node: tailscale status — all nodes listed, connected
# From any node: ping <tailscale-ip-of-other-node> — reaches
# ssh <user>@<tailscale-ip> — works via Tailscale SSH (no raw SSH key needed)
```

**Decision gate:** Headscale + Tailscale gives us a clean mesh with encrypted transport,
automatic NAT traversal, and Tailscale SSH for access. No session recording or RBAC
beyond what Tailscale ACLs provide. **Upgrade path: Teleport** for enterprises needing
session recording, audit logs, and K8s RBAC integration (documented as an alternative
in `docs/architecture.md`).

---

### Checkpoint 1.3 — Firewall hardening

- [x] Ansible playbook: configure firewall rules on all nodes:
  - Only Tailscale port (41641/udp) + Headscale API (if on public IP) exposed externally
  - All inter-node communication goes over Tailscale IPs
- [x] Document mesh topology in `docs/architecture.md` (Layer 0 section)

**Validation:**
```bash
# From outside: nmap <public-ip> → minimal open ports
# Inside mesh: all inter-node traffic over 100.x.x.x (Tailscale IPs)
```

**Decision gate:** Mesh is solid. Proceed to Phase 2. Does Tailscale latency/MTU look
acceptable for K8s etcd traffic? (Should be fine for <10ms on local/DC deployments.)

---

### Checkpoint 1.4 — Phase 1 documentation

- [x] Write `docs/architecture.md` — Layer 0 section: Headscale mesh topology, IP scheme, ACL model
- [x] Write `docs/deployment.md` — Phase 1 section: step-by-step mesh deployment
- [x] Document Teleport as the upgrade/alternative path with a feature comparison table

---

## Phase 2: Infrastructure Core (Layer 1)

**Goal:** Bootstrap the K8s cluster with GPU nodes, deploy the inference engine (vLLM),
API gateway (LiteLLM), secrets management (OpenBao), and the observability stack.
After this phase, you can send an inference request through LiteLLM → vLLM and trace
it in Grafana/Langfuse.

**Entry criteria:** Phase 1 complete. All nodes in mesh, reachable via Tailscale IPs.

**Estimated duration:** 7–10 days

### Checkpoint 2.1 — K8s cluster bootstrap

- [x] Ansible playbook `playbooks/k8s-bootstrap.yml`:
  - Installs k3s on all nodes (lightweight, single-binary, ideal for VPS fleets)
  - Control-plane node becomes server; GPU + storage nodes become agents
  - k3s configured to use Tailscale IPs for inter-node communication
  - Labels GPU nodes: `nvidia.com/gpu=true`, `node.opensas.io/role=gpu`
- [x] Deploy NVIDIA GPU Operator via Helm (from `charts/opensas-infra/`)
- [x] Verify: all nodes `Ready`, GPU allocatable resources visible

**Validation:**
```bash
kubectl get nodes -o wide
# NAME         STATUS   ROLES                       GPU
# control-1    Ready    control-plane,master         -
# gpu-1        Ready    agent                       nvidia.com/gpu: 1

kubectl describe node gpu-1 | grep nvidia.com/gpu
# nvidia.com/gpu:  1
# nvidia.com/gpu:  1  (allocatable)
```

**Decision gate:** k3s vs. full kubeadm? k3s wins on simplicity for VPS fleets. Confirm. -> Confirmed, k3s deployed cleanly.

---

### Checkpoint 2.2 — GPU smoke test on K8s

- [x] Deploy a test pod that runs a small inference on vLLM directly (no LiteLLM yet)
- [x] Helm chart `charts/opensas-infra/templates/vllm-deployment.yaml` (initial version)
- [x] Run a single vLLM pod with a small model on a GPU node
- [x] Verify: `curl` the vLLM API endpoint from within the cluster, get a valid inference response

**Validation:**
```bash
kubectl port-forward svc/vllm-test 8000:8000
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"<model-name>","messages":[{"role":"user","content":"Hello"}]}'
# → valid JSON with choices[0].message.content
```

**Decision gate:** vLLM works on K8s with GPU passthrough. If CUDA version mismatches or GPU
operator issues arise, document workarounds. Consider fallback: vLLM as systemd service
(outside K8s) if GPU scheduling is fragile. -> GPU passthrough worked on first try with GPU Operator.

---

### Checkpoint 2.3 — LiteLLM proxy

- [x] Helm chart for LiteLLM (in `charts/opensas-infra/templates/litellm/`)
- [x] LiteLLM configured with vLLM as the backend
- [x] Configure model routing, basic rate limiting
- [x] Verify: HTTP request to LiteLLM → forwarded to vLLM → response returned

**Validation:**
```bash
kubectl port-forward svc/litellm 4000:4000
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-test" \
  -H "Content-Type: application/json" \
  -d '{"model":"<model-name>","messages":[{"role":"user","content":"Count to 5"}]}'
# → valid response proxied through LiteLLM
```

**Decision gate:** LiteLLM proxies correctly. Do we need a model cache (PVC with pre-downloaded
models) to avoid pulling models on every pod restart? **Yes — create a shared model cache in Phase 3.** -> Yes, vLLM takes 10+ minutes to pull weights. Phase 3 model cache is necessary.

---

### Checkpoint 2.4 — Secrets, Observability & Tracing

- [x] Deploy OpenBao (Vault-compatible) via Helm (`charts/opensas-infra/templates/openbao/`)
  - Or: if secrets are "provided from outside," integrate with external Vault via `ExternalSecret`
- [x] Deploy Prometheus + Grafana via Helm (kube-prometheus-stack)
- [x] Deploy Langfuse (or Phoenix) for LLM tracing
- [x] Wire up: LiteLLM → Langfuse callback for tracing
- [x] Grafana dashboard: GPU utilization, inference latency, token throughput

**Validation:**
```bash
kubectl port-forward svc/grafana 3000:80
# → Grafana UI, dashboards populated
kubectl port-forward svc/langfuse 3001:3000
# → Langfuse UI, traces from LiteLLM visible after inference requests
```

**Decision gate:** Observability stack is functional. Proceed to Phase 3. -> Langfuse v2 deployed successfully.

---

### Checkpoint 2.5 — Phase 2 documentation

- [x] Write `docs/architecture.md` — Layer 1 section: K8s topology, GPU scheduling, inference pipeline
- [x] Write `docs/deployment.md` — Phase 2 section: K8s bootstrap, vLLM, LiteLLM deployment
- [x] Document the tracing pipeline (LiteLLM → Langfuse) — this is the most fragile link

---

## Phase 3: Data Layer (Layer 2)

**Goal:** Deploy MinIO (S3-compatible storage) and establish the shared model cache
for vLLM. After this phase, agents can read/write objects and inference pods pull
models from the shared cache instead of downloading on every restart.

**Entry criteria:** Phase 2 complete. K8s cluster with storage nodes.

**Estimated duration:** 3–5 days

### Checkpoint 3.1 — MinIO deployment

- [ ] Helm chart for MinIO (`charts/opensas-data-privacy/templates/minio/`)
- [ ] MinIO deployed on storage nodes with PVCs
- [ ] Buckets created per `opensas.yaml` config (`documents`, `models-cache`)
- [ ] S3 API reachable from within cluster; credentials injected via OpenBao/k8s secret
- [ ] Validate: `awscli` (or `mc`) from a test pod: put/get/delete objects

**Validation:**
```bash
kubectl run -it --rm minio-test --image=amazon/aws-cli --restart=Never -- \
  aws s3 ls s3://documents --endpoint-url=http://minio:9000
# → empty bucket (or list objects if any)
echo "test" | kubectl run -i --rm minio-put --image=amazon/aws-cli --restart=Never -- \
  aws s3 cp - s3://documents/test.txt --endpoint-url=http://minio:9000
# → upload succeeds
```

**Decision gate:** MinIO works. Single-node MinIO is fine for dev. Multi-node MinIO
needs careful setup — defer to Phase 6 hardening.

---

### Checkpoint 3.2 — Model cache & Phase 2–3 integration

- [ ] Create a shared PVC (RWX or ReadWriteMany) for model weights, or use MinIO as the backing store
- [ ] Update vLLM deployment to mount the model cache
- [ ] Script: pre-download models to the cache
- [ ] Validate: restart vLLM pod → model loads from cache, not from HuggingFace

**Validation:**
```bash
# Delete vLLM pod, watch new pod start
kubectl delete pod -l app=vllm
kubectl logs -l app=vllm -f | grep "Loading model weights"
# → should show loading from /models-cache, not downloading from HF
# → pod start time < 30s (vs. 5-10 min for fresh download)
```

**Decision gate:** Data layer is complete. The stack now has: mesh + K8s + GPU inference
+ API proxy + secrets + observability + S3 storage + model cache.
**This is the minimal viable platform.** Interfaces (Phase 5) and orchestration (Phase 4)
build on top.

> **Note on vector databases:** Qdrant/Milvus/pgvector are intentionally excluded from
> the base bundle. They can be added as optional components in Phase 6 or as a separate
> extension chart. The base stack is agnostic to RAG/vector DB; users add it if needed.

---

### Checkpoint 3.3 — Phase 3 documentation

- [ ] Write `docs/architecture.md` — Layer 2 section: MinIO topology, bucket schema, model cache design
- [ ] Write `docs/deployment.md` — Phase 3 section: MinIO and model cache deployment
- [ ] Add a section in `docs/configuration.md` on how to add optional vector DB components

---

## Phase 4: Orchestration (Layer 3)

**Goal:** Deploy n8n for workflow automation and MCP servers for tool-calling. After this
phase, users can build visual LLM-powered workflows in n8n and agents can call tools via MCP.

**Entry criteria:** Phase 3 complete. LiteLLM, MinIO operational.

**Estimated duration:** 5–7 days

### Checkpoint 4.1 — n8n deployment

- [ ] Helm chart for n8n (`charts/opensas-orchestration/templates/n8n/`)
- [ ] Configure n8n to use internal LiteLLM endpoint for AI nodes
- [ ] Persistent storage for workflows and credentials (MinIO or PVC)
- [ ] Sample workflow: "HTTP webhook → LiteLLM AI node → respond"

**Validation:**
```bash
kubectl port-forward svc/n8n 5678:5678
# → n8n UI accessible
# Import sample workflow from examples/n8n-workflows/
# Execute: webhook → LiteLLM → returns inference result
```

**Decision gate:** n8n is heavy for small deployments (2+ GB RAM). Worth it for visual
workflow building. **Confirm: keep n8n as default, document lightweight alternatives
(Temporal, Windmill) in docs.**

---

### Checkpoint 4.2 — MCP server deployment

- [ ] Deploy a sample MCP server (filesystem type) as a K8s deployment
- [ ] Expose via a ClusterIP service
- [ ] Test: connect an MCP client and list tools
- [ ] Document the MCP server deployment pattern in `docs/workloads/mcp-servers.md`

**Validation:**
```bash
# From a test pod with MCP client:
mcp-client list-tools --server http://mcp-filesystem:8080
# → ["read_file", "write_file", "list_directory", ...]
```

**Decision gate:** MCP servers as K8s deployments works. Should we create an MCP server
Helm chart template? Defer to Phase 6.

---

### Checkpoint 4.3 — Phase 4 documentation

- [ ] Write `docs/architecture.md` — Layer 3 section: n8n integration, MCP server pattern
- [ ] Write `docs/deployment.md` — Phase 4 section: deploying n8n and MCP servers
- [ ] Write `docs/workloads/n8n-workflows.md` — sample workflows and best practices

---

## Phase 5: Interfaces (Layer 4)

**Goal:** Deploy the user-facing applications: LibreChat as the primary chat interface
and a sample Streamlit app demonstrating LLM + S3 connectivity.
After this phase, end users can interact with the stack through a ChatGPT-like UI.

**Entry criteria:** Phase 4 complete. LiteLLM, MinIO operational.

**Estimated duration:** 5–7 days

### Checkpoint 5.1 — LibreChat deployment

- [ ] Helm chart for LibreChat (`charts/opensas-interfaces/templates/librechat/`)
- [ ] Configure LibreChat to use internal LiteLLM endpoint
- [ ] User authentication (local accounts initially; OIDC via Headscale/Teleport deferred)
- [ ] Verify: multi-turn conversation through LibreChat → LiteLLM → vLLM

**Validation:**
```bash
kubectl port-forward svc/librechat 3080:3080
# → LibreChat UI at http://localhost:3080
# Register, create conversation, send message → response streams back
```

**Decision gate:** LibreChat default config uses external API keys. Ensure it works
with a local LiteLLM endpoint without modification. Verify custom endpoint support.

---

### Checkpoint 5.2 — Sample Streamlit app (LLM + S3)

- [ ] Create `examples/streamlit/llm-s3-demo/` — a simple Streamlit app that:
  - Lists objects in a MinIO bucket
  - Accepts a prompt
  - Calls LiteLLM for inference
  - Displays the response with the S3 context
- [ ] Dockerfile + K8s deployment manifest
- [ ] Deploy and verify end-to-end

**Validation:**
```bash
kubectl port-forward svc/streamlit-llm-s3-demo 8501:8501
# → Streamlit app shows S3 bucket contents
# Enter prompt → inference response displayed
```

**Decision gate:** This demonstrates the full stack: mesh → K8s → GPU inference →
MinIO storage → user-facing app. This is the "Hello World" checkpoint for the entire platform.

---

### Checkpoint 5.3 — Bot integrations (deferred)

- [ ] Deploy a Telegram bot that connects to LibreChat or LiteLLM directly
- [ ] Document the bot deployment pattern
- [ ] Hermes framework integration (TBD — Nous Research; details pending)

**Decision gate:** Bots are nice-to-have. Defer to Phase 6 or post-launch unless there's
an immediate need.

---

### Checkpoint 5.4 — Phase 5 documentation

- [ ] Write `docs/architecture.md` — Layer 4 section: LibreChat config, Streamlit app pattern
- [ ] Write `docs/deployment.md` — Phase 5 section: deploying interfaces
- [ ] Write `docs/troubleshooting.md` — common issues and fixes collected from all phases

---

## Phase 6: Integration, Hardening, & Documentation

**Goal:** End-to-end integration testing, production hardening, final documentation,
and CI/CD. This is where the stack goes from "works in dev" to "deployable by others."

**Entry criteria:** Phase 5 complete. All layers operational.

**Estimated duration:** 7–14 days

### Checkpoint 6.1 — End-to-end integration test

- [ ] Script `scripts/integration-test.sh` that:
  - Validates `opensas.yaml`
  - Generates Ansible inventory
  - Deploys full stack (or validates idempotent re-deploy)
  - Runs smoke tests at each layer:
    - Mesh: ping all nodes
    - K8s: all pods Ready
    - Inference: `/v1/chat/completions` returns valid response
    - S3: put/get object
    - LibreChat: health endpoint
    - n8n: health endpoint
    - Streamlit: health endpoint
  - Reports pass/fail per layer

**Validation:**
```bash
./scripts/integration-test.sh config/opensas.dev.yaml
# → 7/7 layers passing
```

---

### Checkpoint 6.2 — Umbrella Helm chart

- [ ] Create `charts/opensas-stack/` — an umbrella chart that deploys all layers
- [ ] Single command: `helm install opensas-stack ./charts/opensas-stack -f values.yaml`
- [ ] Values file generated from `opensas.yaml` + `parse-config.py`
- [ ] Validate: `helm lint`, `helm install --dry-run`

---

### Checkpoint 6.3 — Production hardening

- [ ] Resource limits and requests on all deployments
- [ ] Pod anti-affinity rules for HA (where nodes permit)
- [ ] PersistentVolume retention policies (Retain vs. Delete)
- [ ] MinIO multi-node mode (if >1 storage node)
- [ ] Backup scripts: MinIO buckets, n8n workflows, OpenBao secrets
- [ ] Security: non-root containers, read-only root filesystems, network policies
- [ ] Tailscale ACLs: restrict inter-node communication to necessary ports only

---

### Checkpoint 6.4 — Final documentation pass

- [ ] `docs/architecture.md` — complete all 5 layers
- [ ] `docs/deployment.md` — complete step-by-step guide from VPS provisioning to working stack
- [ ] `docs/security.md` — security model, network policies, ACLs
- [ ] `docs/configuration.md` — complete reference for every config key
- [ ] `docs/development.md` — local dev setup (already written in Phase 0, update if needed)
- [ ] `docs/troubleshooting.md` — collected fixes from all phases
- [ ] `docs/workloads/mcp-servers.md` — how to build and deploy custom MCP servers
- [ ] `docs/workloads/n8n-workflows.md` — sample workflows and best practices
- [ ] `README.md` — project overview, architecture diagram, quickstart link

---

### Checkpoint 6.5 — CI/CD

- [ ] GitHub Actions workflow: `yamllint` → `helm lint` → `helm install --dry-run` (matrix across all charts)
- [ ] `scripts/validate.sh` run in CI
- [ ] Optional: deploy to a test cluster on PR (if test infrastructure available)

---

## Optional Extensions (Post Phase 6)

Components intentionally deferred from the base bundle. These can be added as separate
Helm charts or documented configuration options:

| Extension | Layer | Notes |
|-----------|-------|-------|
| Vector DB (Qdrant/Milvus/pgvector) | 2 | For RAG workloads. Document config pattern, provide example chart. |
| Teleport (upgrade from Headscale) | 0 | For enterprises needing session recording, RBAC, audit. |
| Hermes bot framework | 4 | Nous Research agent framework. TBD when stable. |
| Additional bots (Slack, Discord, Mattermost) | 4 | Follow the Telegram bot pattern. |
| Chainlit | 4 | Alternative to Streamlit for agentic chat UIs. |
| Phoenix (alternative to Langfuse) | 1 | For teams preferring Arize's observability stack. |

---

## Local Validation Matrix

> The hardware listed below describes the *author's development setup*. The repo itself
> is hardware-agnostic. Adapt to your own machines.

| Component | Local Validation | Notes |
|-----------|-----------------|-------|
| Config schema | ✅ `parse-config.py --validate-only` | Pure Python, no infra needed |
| Ansible playbooks | ✅ `ansible-playbook -c local` | Test against localhost |
| K8s cluster | ✅ kind/k3s on dev machine | Control-plane + GPU worker |
| GPU inference (vLLM) | ✅ Local GPU(s) | Run smaller models for dev; full models for perf testing |
| LiteLLM proxy | ✅ K8s pod | Routes to local vLLM |
| MinIO (single-node) | ✅ K8s pod | Multi-node needs >1 storage node |
| n8n | ✅ K8s pod | 2 GB RAM minimum |
| LibreChat | ✅ K8s pod | MongoDB dependency |
| Headscale mesh | ✅ Docker / localhost | Simulate multiple nodes with containers |
| Multi-VPS mesh | ❌ Needs multiple VPSs | Can simulate with VMs (libvirt/VirtualBox) |
| Cross-DC latency | ❌ Needs geographically separated nodes | Simulate with `tc netem` |
| Production load | ❌ Needs production hardware | Dev hardware handles dev load only |
