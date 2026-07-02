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

> To be documented in Phase 2.

---

## Layer 2 — Data & Privacy

> To be documented in Phase 3.

---

## Layer 3 — App & Orchestration

> To be documented in Phase 4.

---

## Layer 4 — Interfaces

> To be documented in Phase 5.
