# OpenSAS Architecture

This document describes the architecture of the Sovereign Automation Stack across all 5 layers.
Each section corresponds to a development phase. As phases are completed, the relevant layer
sections are filled in.

---

## Layer 0 — Mesh & Connectivity

**Phase 1 output.** Zero-trust service mesh connecting all nodes via encrypted WireGuard tunnels.

### Overview

OpenSAS uses **Headscale** (open-source Tailscale-compatible control server) as the mesh
foundation. Every node in the fleet communicates over encrypted WireGuard tunnels managed
by Headscale, reachable by a private Tailscale IP in the `100.64.0.0/10` range (CGNAT).
Direct SSH key access is replaced by Tailscale SSH — authentication and authorization are
managed through the mesh, not per-node SSH keys.

### Components

| Component | Role | Runs On |
|-----------|------|---------|
| **Headscale server** | Control plane — distributes ACLs, manages node state, coordinates DERP relays | Control-plane node |
| **Tailscale client** | WireGuard tunnel + SSH endpoint on every node | All nodes |
| **DERP relay** | Fallback relay for NAT traversal when direct connections fail | Tailscale public DERP (default) or self-hosted |
| **Tailscale SSH** | Authenticated SSH via the mesh — no raw SSH keys | All nodes |

### IP Scheme

| Range | Purpose |
|-------|---------|
| `100.64.0.0/10` | Tailscale IPv4 addresses assigned to each node |
| `fd7a:115c:a1e0::/48` | Tailscale IPv6 addresses |
| Node's actual IP | Underlay — used only for WireGuard traffic (41641/udp) |

Each node gets a stable Tailscale IP and a MagicDNS hostname (`<nodename>.<stack-domain>`).
All inter-service communication uses Tailscale IPs, never raw underlay IPs.

### Topology

```
┌──────────────────────────────────────────────────┐
│                  Headscale Server                 │
│              (control-plane node)                 │
│              http://<ip>:8080                      │
│              SQLite backend                        │
└──────┬───────────────────────┬───────────────────┘
       │                       │
       │ WireGuard (41641/udp) │
       │                       │
┌──────▼──────┐         ┌──────▼──────┐
│  GPU Node 1  │         │  GPU Node 2  │
│ Tailscale IP │         │ Tailscale IP │
│ 100.64.x.y   │◄───────►│ 100.64.x.z   │
│              │  WireGuard direct     │
└──────────────┘         └──────────────┘
       │                       │
       │ Tailscale SSH          │
       │ (no raw SSH keys)     │
       ▼                       ▼
  All inter-node comms    Mesh-encrypted
  over 100.x.x.x IPs      traffic only
```

### Enrollment Flow

1. Headscale server starts on the control-plane node
2. Administrator generates a pre-auth key (`headscale preauthkeys create`)
3. Each node runs `tailscale up --login-server=<headscale-url> --authkey=<key>`
4. Headscale assigns a Tailscale IP and distributes ACLs
5. Tailscale SSH is enabled on each node (`tailscale set --ssh`)
6. Nodes are reachable by MagicDNS: `ssh root@<nodename>.<stack-domain>`

### Firewall Model

After enrollment, firewall rules restrict external traffic:

| Port | Protocol | Purpose | Exposure |
|------|----------|---------|----------|
| 41641 | UDP | Tailscale/WireGuard direct connections | Open to all (required for mesh NAT traversal) |
| 8080 | TCP | Headscale API | Tailscale IPs only (post-enrollment) |
| 22 | TCP | SSH | Local network only → replaced by Tailscale SSH |

All inter-node traffic (K8s etcd, service mesh, application) flows over Tailscale IPs
on the `100.64.0.0/10` network and is encrypted by WireGuard.

### Decision: Headscale vs. Teleport

Headscale is the default for Phase 1. The upgrade path to Teleport is documented below
for enterprises needing additional capabilities.

| Feature | Headscale + Tailscale | Teleport |
|---------|----------------------|----------|
| **WireGuard encryption** | ✅ | ✅ |
| **NAT traversal** | ✅ (DERP + STUN) | ✅ |
| **MagicDNS** | ✅ | ✅ |
| **SSH access** | Tailscale SSH | Teleport Node (tsh) |
| **Session recording** | ❌ | ✅ |
| **Audit logging** | ❌ | ✅ (full session replay) |
| **RBAC** | Tailscale ACLs (basic) | ✅ (roles, traits, OIDC) |
| **K8s RBAC integration** | ❌ | ✅ |
| **Database access proxy** | ❌ | ✅ |
| **OIDC/SAML SSO** | ✅ (limited) | ✅ (full) |
| **Air-gapped support** | ✅ | ✅ (self-hosted) |
| **Fleet size** | <50 nodes (SQLite) / unlimited (Postgres) | Unlimited |
| **Open source** | ✅ (BSD-3) | ✅ (AGPL) |
| **Complexity** | Low — single binary server | Medium — requires auth connector |

**When to switch to Teleport:**
- Compliance requirements (SOC2, HIPAA) requiring session recording and audit trails
- Need for K8s RBAC integration (kubectl access via `tsh`)
- Database access proxy for Postgres/MySQL behind the mesh
- Enterprise SSO with granular role-based access

The Teleport Helm chart lives at `charts/opensas-teleport/` and can be deployed
as a drop-in replacement for Headscale by updating `mesh.provider: teleport` in
`opensas.yaml`.

### References

- [Headscale documentation](https://headscale.net/)
- [Tailscale SSH documentation](https://tailscale.com/kb/1193/tailscale-ssh)
- [WireGuard protocol](https://www.wireguard.com/)
- [Teleport documentation](https://goteleport.com/docs/)

---

## Layer 1 — Infrastructure & Day-2 Operations

**Phase 2 output.** Kubernetes core with GPU passthrough, secrets management, and observability.

### Overview

Layer 1 sits on top of the Layer 0 mesh. It provides a lightweight Kubernetes cluster (k3s) optimized for multi-node VPS fleets. Node networking is routed entirely over the Tailscale underlay (Flannel via `tailscale0`), ensuring all K8s API and pod-to-pod traffic is WireGuard-encrypted.

This layer handles the heavy lifting of AI workloads: GPU resource allocation (via NVIDIA GPU Operator), model inference (vLLM), and API routing (LiteLLM proxy).

### Components

| Component | Role | Deployed via |
|-----------|------|--------------|
| **k3s** | Lightweight K8s orchestrator. Control-plane nodes run `server`, others run `agent`. | Ansible |
| **NVIDIA GPU Operator** | Automates provisioning of NVIDIA software components on K8s (driver, container toolkit, device plugin). | Helm (`nvidia`) |
| **vLLM** | High-throughput memory-efficient LLM serving engine. Deployed with PagedAttention and continuous batching enabled. | Helm (`opensas-infra`) |
| **LiteLLM** | API Gateway. Provides a unified OpenAI-compatible endpoint, load balancing, cost tracking, and rate limiting. | Helm (`opensas-infra`) |
| **OpenBao** | Self-hosted Vault alternative for secrets management and injection. | Helm (`opensas-infra`) |
| **Prometheus & Grafana** | Cluster and GPU observability stack (metrics aggregation). | Helm (`kube-prometheus-stack`) |
| **Langfuse** | LLM tracing observability. Captures prompt chains, latency, and token metrics from LiteLLM. | Helm (`opensas-infra`) |

### Topology & Traffic Flow

1. **Inference Request:** A service (e.g., LibreChat in Layer 4) sends an OpenAI-formatted request to `http://opensas-infra-litellm.opensas.svc.cluster.local:4000`.
2. **Routing & Auth:** LiteLLM validates the API key, checks rate limits, and routes the request.
3. **Tracing:** LiteLLM asynchronously sends a start trace event to the Langfuse backend.
4. **Execution:** The request hits `http://opensas-infra-vllm.opensas.svc.cluster.local:8000`. vLLM schedules the prompt on the GPU and streams the generated tokens back.
5. **Completion:** LiteLLM logs the total cost/tokens and sends the final trace to Langfuse.

### GPU Scheduling

Nodes with GPUs are labeled during bootstrap (`nvidia.com/gpu=true`, `node.opensas.io/role=gpu`). 
The `opensas-infra` chart uses these labels via `nodeSelector` and `tolerations` to ensure vLLM pods land on nodes with matching hardware and exclusive GPU access.

### Tracing Pipeline

Tracing is the most fragile link in LLM infrastructure. OpenSAS uses Langfuse (v2), integrated via LiteLLM's `success_callback` and `failure_callback`. 
- **LiteLLM** injects Langfuse keys as environment variables (`LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`).
- Traces capture not just the prompt and completion, but the exact cost (calculated by LiteLLM) and latency per token.

---

## Layer 2 — Data & Privacy

> To be documented in Phase 3.

---

## Layer 3 — App & Orchestration

> To be documented in Phase 4.

---

## Layer 4 — Interfaces

> To be documented in Phase 5.
