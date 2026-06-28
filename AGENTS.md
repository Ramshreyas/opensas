# Agents.md — Sovereign Automation Stack

## Project Overview

This repository contains the **Sovereign Automation Stack (OpenSAS)** — a turnkey, zero-data-leak, fully private AI and automation infrastructure deployed within secure environments (VPC or on-premise bare-metal). The one-pager at `opensas.md` is the canonical architecture reference.

The stack is a 5-tier modular architecture built bottom-up (Layer 0 is the foundational mesh, Layer 4 is the user-facing interface):

| Layer | Name | Core Components |
|-------|------|----------------|
| **0** | Mesh & Connectivity | Teleport (Community Edition), WireGuard, node enrollment & trust propagation |
| **1** | Infrastructure & Day-2 | vLLM, LiteLLM Proxy, OpenBao, Phoenix (Arize) / Langfuse, Grafana |
| **2** | Data & Privacy | MinIO, Qdrant/Milvus/pgvector, IAM Policy Mapping |
| **3** | App & Orchestration | n8n (self-hosted), MCP Servers, Python/FastAPI microservices |
| **4** | Interfaces | LibreChat, Slack/Discord/Mattermost bots, Streamlit, Chainlit |

---

## Repository Structure

```
opensas/
├── AGENTS.md              # ← This file — Pi context & conventions
├── opensas.md             # One-pager (canonical architecture reference)
├── README.md              # Project README
├── LICENSE                # License file
│
├── .github/
│   └── workflows/         # GitHub Actions CI/CD (cloud-agnostic)
│
├── charts/                # Helm charts for stack components (bottom-up order)
│   ├── opensas-stack/     # Umbrella chart (deploys all layers)
│   ├── opensas-teleport/  # Layer 0 — Mesh & Connectivity
│   ├── opensas-infra/     # Layer 1 — Infrastructure & Day-2
│   ├── opensas-data-privacy/ # Layer 2 — Data & Privacy
│   ├── opensas-orchestration/ # Layer 3 — App & Orchestration
│   └── opensas-interfaces/ # Layer 4 — Interfaces
│
├── config/                # Reference configs & examples
│   ├── teleport/          # Teleport cluster config, roles, RBAC
│   ├── wireguard/         # WireGuard underlay configs
│   ├── litellm/
│   ├── n8n/
│   ├── vllm/
│   └── vector-db/
│
├── docs/                  # Additional documentation
│   ├── architecture.md
│   ├── deployment.md
│   ├── security.md
│   └── workloads/
│
├── examples/              # Example workflows, MCP servers, agent configs
│   ├── n8n-workflows/
│   ├── mcp-servers/
│   └── fastapi-agents/
│
└── scripts/               # Utility scripts
    ├── bootstrap.sh
    ├── teardown.sh
    └── validate.sh
```

---

## Naming & Style Conventions

### File & Directory Names
- **kebab-case** for all files and directories: `inference-engine`, `api-gateway`, `my-config.yaml`
- Helm chart names prefixed with `opensas-`: `opensas-vllm`, `opensas-librecchat`
- Markdown files: lowercase with dashes (`deployment-guide.md`), except `README.md`, `AGENTS.md`, `LICENSE`
- Scripts: `snake_case.sh`

### YAML Conventions
- 2-space indentation, no tabs
- No trailing whitespace
- Trailing `---` not used (except for Helm values files where conventional)
- Lists use `- ` with a space after the dash
- Boolean values: `true` / `false` (no quotes, no `yes`/`no`)
- Strings: unquoted unless they contain special characters

### Environment Variables
- `SCREAMING_SNAKE_CASE`
- Prefix with `OPEN SAS_` where applicable

### Commit Messages
Conventional Commits format:
```
<type>(<scope>): <short description>

[optional body]
```
Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `style`, `perf`
Scopes (in stack order): `mesh`, `infra`, `data`, `orchestration`, `interfaces`, `charts`, `docs`, `ci`

Examples:
- `feat(mesh): add Teleport Helm chart with WireGuard underlay`
- `feat(infra): add vLLM Helm chart with GPU tolerations`
- `docs(data): document pgvector connection pooling`
- `fix(orchestration): correct n8n webhook secret injection`
- `feat(interfaces): configure LibreChat auth provider

---

## Development Workflow

### Branching
- `main` — production-ready, always deployable
- `develop` — integration branch for feature work
- `feat/<short-description>` — feature branches off `develop`
- `fix/<short-description>` — bugfix branches off `develop`
- `docs/<short-description>` — documentation-only changes, can go to `main` directly

### Pull Requests
- PRs target `develop` (or `main` for docs-only/hotfixes)
- Title follows conventional commit format
- Description should reference what layer(s) are affected

### CI/CD (GitHub Actions)
- Must be cloud-agnostic — no provider-specific runners or secrets
- Lint: `yamllint` on YAML files, Helm chart linting
- Test: chart install dry-run, validation scripts
- No hardcoded credentials; everything via GitHub Environments / OIDC where needed

---

## Architecture & Design Principles

1. **Zero data leak** — no bytes leave the private infrastructure
2. **Cloud agnostic** — deployable to any K8s cluster (k3s, Rancher, EKS, AKS, GKE, bare-metal) or fleet of VPS
3. **Modular** — each layer is independently deployable; no cross-layer hard dependencies
4. **Production-grade** — observability, tracing, secrets management, and cost governance built in
5. **Day-2 operations first** — monitoring, upgrades, backups, and evals are not afterthoughts

### Portability Constraints
- No reliance on managed cloud services (no EFS, no RDS, no CloudWatch)
- All storage via MinIO (S3-compatible) or local PVs
- Ingress via any standard IngressController / CNI
- Container images from registries that work in air-gapped environments (GHCR, Docker Hub with mirroring support)
- VPS fleet orchestrated via Teleport mesh (not cloud-specific SSM, Session Manager, or console access)

---

## Pi Usage Guidelines

### Working Style
- Always read `opensas.md` first if you need architectural context
- When modifying Helm charts, run `helm lint` before considering work done
- For YAML changes, prefer `edit` over `write` to preserve unrelated content
- When proposing new components, reference the 5-layer architecture (Layers 0–4) and explain which layer it belongs to
- Layer 0 (Teleport mesh) is a prerequisite for all other layers — never suggest deploying Layers 1–4 without the mesh foundation
- Teleport is the identity plane for the entire fleet; prefer Teleport roles/RBAC over separate SSH key management
- Keep responses concise; show file paths clearly

### Available Slash Commands (Skills)

Skills are in `.pi/skills/`. Enable via `/settings` or they're auto-discovered.

| Command | Description |
|---------|-------------|
| `/skill:commit-push` | Stage all changes, get a suggested conventional commit message, commit, and push |
| `/skill:document-changes` | Scan recent git changes and update relevant documentation files |
| `/skill:update-agents` | Review current conventions and update AGENTS.md with any new patterns established |

### Context Loading
- Pi auto-loads this `AGENTS.md` at startup
- Run `/reload` after updating `AGENTS.md` or any skill files

---

## Getting Started

```bash
# Clone
git clone <repo-url>
cd opensas

# Initialize environment (first time)
./scripts/bootstrap.sh

# Lint all Helm charts
for chart in charts/*/; do helm lint "$chart"; done

# Dry-run a chart
helm install --dry-run --debug opensas-stack ./charts/opensas-stack
```

---

## Directory Creation Checklist (Pre-Flight)

This repo is greenfield. The following directories should be created as the project evolves:

- [ ] `.github/workflows/` — CI/CD pipelines
- [ ] `charts/` — Helm charts for each layer (including `opensas-teleport`)
- [ ] `config/` — reference configurations (including `teleport/` and `wireguard/`)
- [ ] `docs/` — architecture, deployment, security docs
- [ ] `examples/` — n8n workflows, MCP server examples, agent code
- [ ] `scripts/` — bootstrap, teardown, validation scripts
- [ ] `.pi/skills/` — Pi slash command skills
