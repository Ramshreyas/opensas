# OpenSAS Deployment Guide

Step-by-step deployment guide for the Sovereign Automation Stack. Each phase builds
on the previous one. Follow in order.

---

## Prerequisites

- **Ansible ≥ 2.16** installed on your control machine
- **Python 3 ≥ 3.10** with `jsonschema` (`pip3 install jsonschema pyyaml`)
- **Nodes** accessible via SSH (with root or sudo access)
- **`opensas.yaml`** configured for your fleet (see `docs/configuration.md`)

---

## Phase 0: Developer Sandbox

Already completed. This establishes the dev toolchain, config schema, and validation pipeline.

**Quick re-validate:**
```bash
./scripts/bootstrap.sh
python3 scripts/parse-config.py config/opensas.dev.yaml --validate-only
./scripts/validate.sh
```

---

## Phase 1: Mesh Foundation (Layer 0)

**Goal:** Establish the zero-trust service mesh using Headscale across all nodes.
After this phase, every node communicates over encrypted WireGuard tunnels, reachable
by a private Tailscale IP, and direct SSH key access is replaced by Tailscale SSH.

**Entry criteria:** Phase 0 complete. Nodes accessible via SSH.

---

### Step 1.1: Deploy Headscale control plane

The Headscale server runs on the control-plane node and manages the entire mesh.

```bash
# Generate Ansible inventory from your config
python3 scripts/parse-config.py config/opensas.dev.yaml --output-inventory --output-vars

# Deploy Headscale on the control-plane node
ansible-playbook -i inventory/opensas-dev/hosts.yml playbooks/headscale.yml
```

**What happens:**
1. Installs Headscale from the official package repository
2. Configures SQLite backend (fine for <50 nodes)
3. Sets up Tailscale IP ranges (`100.64.0.0/10`, `fd7a:115c:a1e0::/48`)
4. Starts the Headscale service on port 8080
5. Generates a pre-auth key for node enrollment
6. Stores the key at `/etc/opensas/headscale-preauth.key` on the control-plane node

**Verify:**
```bash
# On the control-plane node:
curl http://localhost:8080/health
# → {"status": "pass"}  or  HTTP 200

headscale nodes list
# → (empty until nodes enroll)
```

**Single-node dev note:** In the dev config (`opensas.dev.yaml`), the same machine
(yoneda) is control-plane, GPU, and storage. Headscale runs on localhost, and the
Tailscale client on the same machine will connect to `http://127.0.0.1:8080`.
This works correctly — Headscale and Tailscale coexist on the same host.

---

### Step 1.2: Enroll nodes in the mesh

Install Tailscale on every node and enroll them with the Headscale control server.

```bash
ansible-playbook -i inventory/opensas-dev/hosts.yml playbooks/tailscale-enroll.yml
```

**What happens:**
1. Installs Tailscale client on all nodes (using the official install script)
2. Reads the pre-auth key from the control-plane node
3. Runs `tailscale up` on each node, pointing to the Headscale server
4. Enables Tailscale SSH (`tailscale set --ssh`)
5. Verifies each node is online and reachable

**Verify:**
```bash
# On the control-plane node:
headscale nodes list
# → shows all enrolled nodes with their Tailscale IPs

# From any node, ping another node by Tailscale IP:
ping 100.64.x.y

# SSH via Tailscale SSH (no raw SSH keys needed):
ssh root@<nodename>.opensas.local
```

**Idempotency:** `tailscale-enroll.yml` is safe to re-run. Already-enrolled nodes
are detected and skipped. Pre-auth keys are reusable by default.

---

### Step 1.3: Harden firewall rules

Restrict external ports to only what the mesh needs. All inter-node communication
flows over encrypted Tailscale IPs.

```bash
ansible-playbook -i inventory/opensas-dev/hosts.yml playbooks/firewall.yml
```

**What happens:**
1. Detects the firewall backend (UFW, firewalld, or iptables/nftables)
2. Allows only:
   - **41641/udp** — Tailscale WireGuard data plane (must be open for NAT traversal)
   - **22/tcp** — SSH from local network only (transitional, replaced by Tailscale SSH)
3. Drops all other incoming traffic
4. Loopback deployments (`ansible_host = 127.0.0.1`) skip external firewall rules
   (applying them to loopback would lock out the dev machine)

**Verify:**
```bash
# On each node:
sudo ufw status verbose        # (UFW)
sudo firewall-cmd --list-all   # (firewalld)
sudo iptables -L INPUT -n      # (iptables)

# From outside the mesh:
nmap -p 22,8080,41641 <public-ip>
# → 41641/udp open|filtered, 22 filtered, 8080 filtered
```

**Multi-VPS note:** When deploying to real VPS nodes with public IPs, the firewall
rules are applied on the external interface. `nmap` from outside should show only
the Tailscale port as open. All other services (K8s API, MinIO, LiteLLM, etc.) are
reachable only through the Tailscale mesh.

---

### Step 1.4: Phase 1 complete — validation checklist

```bash
# All playbooks run green
ansible-playbook -i inventory/opensas-dev/hosts.yml playbooks/headscale.yml
ansible-playbook -i inventory/opensas-dev/hosts.yml playbooks/tailscale-enroll.yml
ansible-playbook -i inventory/opensas-dev/hosts.yml playbooks/firewall.yml

# Verify mesh health
# On control-plane node:
headscale nodes list        # All nodes listed
tailscale status            # All nodes connected
tailscale ping <nodename>   # Direct WireGuard connection (no DERP relay)

# SSH via Tailscale SSH
ssh root@<nodename>.opensas.local  # Works without raw SSH key

# Firewall active
sudo ufw status             # "Status: active" (non-loopback deployments)
```

---

## Phase 2: Infrastructure Core (Layer 1)

> To be documented in Phase 2.

---

## Phase 3: Data Layer (Layer 2)

> To be documented in Phase 3.

---

## Phase 4: Orchestration (Layer 3)

> To be documented in Phase 4.

---

## Phase 5: Interfaces (Layer 4)

> To be documented in Phase 5.

---

## Phase 6: Integration, Hardening & Documentation

> To be documented in Phase 6.
