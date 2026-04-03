# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

A local Kubernetes learning environment using kind (Kubernetes in Docker) with a full GitOps and service mesh stack: Istio, ArgoCD, Argo Rollouts, Kargo, and Kubernetes Dashboard.

## Common Commands

All operations go through the Makefile (preferred) or the build scripts. The Makefile delegates to PowerShell (`build.ps1`) on all platforms.

### Cluster Lifecycle
```bash
make create-cluster       # Create kind cluster
make delete-cluster       # Delete kind cluster
make setup                # Full setup: create cluster + install all components
make teardown             # Full teardown: delete cluster + cleanup
```

### Component Installation
```bash
make install              # Install all components interactively
make install-quiet        # Install all components non-interactively
make install-istio
make install-argocd
make install-rollouts
make install-kargo
make install-dashboard
make install-cert-manager
make setup-infrastructure # SSL certificates + Istio gateway routing
```

### Verification & Status
```bash
make verify               # Verify cluster and all components
make status               # Check status of all components
```

### UI Access
```bash
make dashboard            # Port-forward Kubernetes Dashboard
make argocd-ui            # Port-forward ArgoCD UI
make kargo-ui             # Port-forward Kargo UI
make rollouts-ui          # Port-forward Argo Rollouts UI
make expose-gateway       # Expose Istio gateway (unified access)
```

### Helm Chart Operations
```bash
make helm-lint            # Lint all Helm charts
make helm-template        # Render templates for review
make helm-test            # Run Helm tests
make helm-verify          # Full verify: lint + template + test
make helm-build           # Update chart dependencies
make helm-package         # Package charts to .tgz in helm-charts/packages/
```

For Linux/macOS, `build.sh` provides equivalent commands: `./build.sh <command>`.

## Architecture

### Stack
- **kind** — local Kubernetes cluster runtime
- **Istio** v1.23.2 — service mesh; demo profile; sidecar injection enabled in `default` namespace
- **ArgoCD** — GitOps CD; admin password auto-saved to `credentials/`
- **Argo Rollouts** v1.7.2 — canary/blue-green deployments; integrates with Istio for traffic splitting
- **Kargo** v1.8.4 — multi-stage promotion pipeline (Warehouse → Stages); integrates with ArgoCD
- **cert-manager** v1.14.0 — SSL certificates (self-signed for local, Let's Encrypt for prod)
- **Kubernetes Dashboard** — web UI; token auto-saved to `credentials/dashboard-token.txt`

### Directory Layout
- `scripts/` — PowerShell (.ps1) automation scripts (primary)
- `scripts/linux/` — Bash (.sh) equivalents for Linux/macOS
- `manifests/infrastructure/` — Istio gateway, cert-manager issuers, path-based routing
- `manifests/examples/` — ArgoCD application and Kargo project examples
- `helm-charts/app-template/` — Main Helm chart (v2.0.0) with three optional subcharts
- `deployments/spring-kotlin-app/` — Example Spring Kotlin app deployment
- `docs/` — Deployment guide and Dashboard usage guide

### Helm Chart Architecture

`helm-charts/app-template` is the primary chart. It selects between a standard `Deployment` or an Argo Rollouts `Rollout` object based on values. Three optional subcharts in `app-template/charts/`:

| Subchart | Purpose |
|---|---|
| `argo-rollouts` | Rollout strategy (canary/blue-green), analysis templates |
| `istio-routing` | VirtualService, DestinationRule, traffic weights |
| `kargo-config` | Warehouse, Stages, promotion tasks |

Each subchart is independently enabled/disabled via values (e.g., `argoRollouts.enabled`, `istioRouting.enabled`, `kargoConfig.enabled`).

### Namespace Organization
- `istio-system` — Istio control plane
- `argocd` — ArgoCD
- `argo-rollouts` — Argo Rollouts controller
- `kargo` — Kargo
- `kubernetes-dashboard` — Dashboard
- `cert-manager` — cert-manager
- `default` — application workloads (Istio sidecar injection enabled)

### Infrastructure Routing
After `make setup-infrastructure`, tools are accessible via the Istio IngressGateway using path-based routing defined in `manifests/infrastructure/tools-routing.yaml`. Credentials are stored in `credentials/` (git-ignored).

## CI/CD

GitHub Actions (`.github/workflows/helm-ci.yml`) triggers on changes to `helm-charts/` or `deployments/`:
1. **Lint & Test** — Helm lint + template rendering for multiple scenarios + package
2. **Integration Test** — Deploys to a temporary kind cluster with Istio and Argo Rollouts CRDs
3. **Security Scan** — Trivy scan on helm-charts directory, results uploaded to GitHub Security tab

## Key Conventions

- PowerShell scripts are the source of truth; Bash scripts in `scripts/linux/` mirror them
- Installation scripts are idempotent — safe to re-run
- Credentials (tokens, passwords) are auto-generated and written to `credentials/` (git-ignored)
- Chart dependencies must be updated (`make helm-build`) before linting or packaging
- Kargo uses the newer PromotionTask API (not the legacy Promotion API)
