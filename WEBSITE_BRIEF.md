# OpenSAS — Website Brief

> **Handoff document for the `opensas-site` repository.**
> The canonical technical architecture is in [`opensas.md`](opensas.md). This brief translates that architecture into a website brief — covering positioning, audience, messaging, use cases, visuals, and call to action.
>
> **Tone:** Security-hardened pragmatist, engineer-to-engineer. No fluff. No hype. Respect the reader's expertise.

---

## 1. Identity & Tagline

| Field | Value |
|-------|-------|
| **Name** | OpenSAS |
| **Expanded** | Sovereign Automation Stack |
| **Tagline** | *Private AI infrastructure. No data leaves your network.* |
| **Alternative tagline (hero)** | *Run autonomous agents on your hardware, under your control. Zero data leak, zero vendor lock-in.* |
| **Style note** | Use "OpenSAS" as the primary brand name. "Sovereign Automation Stack" is the full form used on first mention or in formal/legal contexts. |

### Visual Identity Guidance

- The **5-layer stack diagram** (see Section 3) is the hero visual of the site. It should be an interactive diagram, not a static image — each layer clickable/expandable to reveal detail.
- Color palette should convey **security + infrastructure**: deep blues, slate grays, with an accent color (amber or teal) for the mesh/connectivity layer.
- Iconography: avoid generic cloud icons. Use hardware/rack/server motifs where possible — this is about *your hardware*, not someone else's cloud.

---

## 2. Audience & Messaging By Persona

OpenSAS speaks to three distinct personas. The homepage must work for all three; deeper pages can target individually.

### Persona 1: CISO / Security Architect

| Concern | OpenSAS Answer |
|---------|----------------|
| "Our data can't touch third-party APIs." | Zero data leak by design. No byte leaves your private infrastructure — not even for inference. |
| "We need audit trails for AI workloads." | Teleport session recording + Phoenix/Langfuse tracing + OpenBao audit logs. Every action is captured. |
| "Shadow IT is deploying AI tools." | One approved platform. IAM-pinned permissions. No ungoverned AI usage. |

**Message:** *Your AI workloads inherit your existing security posture, not weaken it.*

### Persona 2: CTO / VP Engineering

| Concern | OpenSAS Answer |
|---------|----------------|
| "I don't want to rebuild the wheel." | Turnkey deployment blueprint — not a DIY toolkit. 6–8 weeks to production. |
| "I need flexibility in models and tools." | vLLM for any open-weight model, n8n for visual workflows, MCP for custom tool integration. Tech choices are yours. |
| "Vendor lock-in scares me." | Every component is open-source or open-core. No proprietary APIs. No exit cost. |

**Message:** *Ship production AI infrastructure without betting the architecture on a single vendor.*

### Persona 3: DevOps / Platform Engineer

| Concern | OpenSAS Answer |
|---------|----------------|
| "I don't want another pet project to maintain." | Day-2 operations are built in — observability, cost tracking, upgrades, evals. |
| "Can I deploy this on our existing infra?" | K8s, raw Helm, any VPS. No cloud-specific dependencies. Works in air-gapped environments. |
| "Who's going to support this after handoff?" | Internal team handover and training are part of the engagement. Your team owns it. |

**Message:** *Infrastructure you'd build yourself, if you had 8 weeks to spare.*

---

## 3. The Five-Layer Stack (Hero Visual)

This is the centerpiece of the website. Present it as an **interactive vertical stack**, descending from highest abstraction to foundation:

```
┌─────────────────────────────────┐
│  4. Interfaces                  │  ← User-facing: LibreChat, Slack bots, Streamlit
├─────────────────────────────────┤
│  3. App & Orchestration         │  ← Logic: n8n, MCP Servers, FastAPI agents
├─────────────────────────────────┤
│  2. Data & Privacy              │  ← Memory: MinIO, Qdrant, pgvector, IAM
├─────────────────────────────────┤
│  1. Infrastructure & Day-2      │  ← Engine: vLLM, LiteLLM, OpenBao, Grafana
├─────────────────────────────────┤
│  0. Mesh & Connectivity         │  ← Fabric: Teleport, WireGuard
└─────────────────────────────────┘
```

**Interaction:** Clicking a layer expands it to show the bullet points from `opensas.md`. The layer numbers should be prominent — they're part of the identity (people will say "we're on Layer 2" internally).

**Mobile:** Stack collapses to an accordion or horizontal swipe.

---

## 4. Use Cases

Three concrete scenarios. Each should get its own page/case study slot eventually, but the homepage needs at minimum a summary grid.

### Use Case A: Private Agentic Workflows for Regulated Industries

> A financial services firm wants to deploy LLM-powered compliance agents that review internal communications, flag policy violations, and draft regulatory filings — all on customer data that **cannot** leave their VPC.

**Why OpenSAS:** vLLM runs on their GPUs. MinIO stores internal documents. n8n orchestrates the review pipeline. Teleport provides audit-grade SSH access. Zero bytes touch the public internet.

### Use Case B: Internal Developer Platform with AI-Augmented Tooling

> A platform team wants to give their engineers AI-powered code review, documentation generation, and incident response bots — without sending proprietary source code to a third-party API.

**Why OpenSAS:** MCP servers connect to internal git repos and observability stacks. LiteLLM routes requests across locally-hosted models. Langfuse traces every prompt for debugging.

### Use Case C: Multi-Tenant AI Sandbox for Consulting / Services

> A consultancy needs isolated AI environments per client — each client's data, models, and workflows must be strictly partitioned, all running on the consultancy's own hardware.

**Why OpenSAS:** Layer 3 IAM mapping enforces per-tenant data isolation. The Teleport mesh provides per-client access controls. Kubernetes namespaces + Qdrant collections handle the rest.

---

## 5. Competitive Positioning

Not naming competitors directly, but the website should implicitly draw these contrasts:

| Instead of... | OpenSAS gives you... |
|---------------|---------------------|
| Using OpenAI/Anthropic APIs | Zero data leaving your network |
| DIY-ing from GitHub READMEs | A production-tested, integrated blueprint |
| A single-model platform | Any open-weight model, swap any time |
| Cloud-managed AI services | Deploy on a $40/month VPS or a bare-metal rack |
| Opaque pricing and cost tokens | Full cost visibility: GPU utilization, token spend per user |

**The core differentiator (one sentence for the hero section):**

> *OpenSAS is the infrastructure you'd build for production AI workloads — if you had a dedicated team and 8 weeks. We give you the blueprint, the integration, and the handover. You keep the keys.*

---

## 6. Business Model

Clearly state what the buyer gets:

| What | Details |
|------|---------|
| **Engagement** | 6–8 week consulting engagement |
| **Deliverable** | Production-grade IaC blueprint deployed in your environment (Helm charts, configs, automated scripts) |
| **Included** | Architecture design, security assessment, n8n/MCP workflow development, internal team training |
| **Outcome** | Your team owns and operates the stack independently post-handover |
| **Licensing** | All components are open-source or open-core. No per-seat or per-token license fees on the platform itself. You pay only for your infrastructure (VPS, GPU, storage). |
| **Optional** | Retainer for workflow development, optimization, or upgrades |

**Pricing note for the website:** Don't list prices. Guide toward a "Schedule a discovery call" CTA. But be transparent about *what* they're paying for — services, not software licenses.

---

## 7. Call to Action

Primary CTA (hero section, sticky nav, footer):

> **Deploy your first agent in 6 weeks →** [Schedule a discovery call]

Secondary CTA (after architecture section, use cases):

> **See the blueprint →** [Download the one-pager (`opensas.md`)]

Tertiary CTA (blog/case study pages):

> **Read the technical deep dive →** [Blog / Architecture walkthrough]

---

## 8. Site Structure (Suggested)

```
/
├── Hero + 5-layer stack visual
├── The Problem (data privacy, vendor lock-in)
├── The Stack (animated/interactive layer diagram)
├── Use Cases (3 cards)
├── How It Works (engagement model, 6–8 weeks)
├── For Engineers (FAQ: tech stack, deployment requirements, air-gap support)
└── CTA / Contact

Additional pages:
├── /architecture    — Full layer-by-layer breakdown from opensas.md
├── /use-cases       — Expanded case studies
├── /blog            — Technical posts, benchmarks, update logs
└── /contact         — Booking form
```

**Design note:** Keep the homepage single-scroll, dense with information. The audience (engineers, technical leaders) prefers substance over whitespace. Each section earns its keep with specific claims, not generic statements.

---

## 9. Tone & Voice Reference

| Do | Don't |
|----|-------|
| "Zero data leaves your network." | "Your data is safe with us." |
| "vLLM serves open-weight models on your GPUs." | "AI-powered cloud magic." |
| "6–8 weeks to production deployment." | "Transform your business overnight." |
| "Every layer is independently deployable." | "Seamless end-to-end solution." |
| "Teleport session recording + OpenBao audit logs." | "Enterprise-grade security." |

**Guiding principle:** Write as one engineer explaining a well-architected system to another engineer. If a sentence would sound out of place in a technical RFC, it doesn't belong on the site.

---

## 10. Content Inventory

Assets that need to be created for the site:

- [ ] 5-layer interactive stack diagram (SVG/JS)
- [ ] Deployment flow diagram (VPS fleet → Teleport mesh → K8s → stack layers)
- [ ] 3 use case illustrations (regulated industry, dev platform, multi-tenant)
- [ ] Architecture deep-dive page (translated from `opensas.md`)
- [ ] FAQ: Deployment requirements (K8s, GPU, storage minimums)
- [ ] FAQ: Air-gapped / disconnected environment support
- [ ] FAQ: Model compatibility (all open-weight models via vLLM)
- [ ] Blog: "Why we built a private AI stack" — founder/lead post
- [ ] Blog: Technical walkthrough of a Layer 0 → Layer 4 deployment
