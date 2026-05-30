# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

A local Kubernetes learning environment using kind (Kubernetes in Docker) with a full GitOps and service mesh stack: Istio, ArgoCD, Argo Rollouts, Kargo, and Kubernetes Dashboard.

## Common Commands

Use `./build.sh <target>` on macOS/Linux, or `.\build.ps1 <target>` on Windows. Both expose the same target names. The Makefile is an alternative on Windows but several of its `install*` and `verify` targets have a path bug (`./scripts/` instead of `./scripts/windows/`) and will fail — prefer `.\build.ps1` on Windows.

### Cluster Lifecycle
```bash
./build.sh create-cluster     # Create kind cluster (named my-local-cluster)
./build.sh delete-cluster     # Delete kind cluster
./build.sh setup              # Full setup: create cluster + install all components
./build.sh teardown           # Full teardown: delete cluster + cleanup
```

### Component Installation
```bash
./build.sh install            # Install all components (non-interactive on macOS/Linux)
./build.sh install-cert-manager
./build.sh install-istio
./build.sh install-argocd
./build.sh install-rollouts
./build.sh install-kargo
./build.sh install-dashboard
./build.sh install-otel-operator
```

### Verification & Status
```bash
./build.sh verify             # Verify cluster and all components
```

### Infrastructure
```bash
./build.sh setup-infrastructure   # Apply Istio gateway + cert-manager routing
./build.sh expose-gateway         # Port-forward Istio gateway → https://localhost:8443
```

### UI Access
```bash
./build.sh dashboard          # kubectl proxy → http://localhost:8001/.../kubernetes-dashboard/
./build.sh argocd-ui          # Port-forward ArgoCD UI → https://localhost:8080
./build.sh kargo-ui           # Port-forward Kargo UI → http://localhost:8081
./build.sh rollouts-ui        # Launch Argo Rollouts dashboard (plugin in tools/)
```

Credentials are auto-saved to `credentials/` (git-ignored): `argocd-credentials.txt`, `kargo-credentials.txt`, and `service-accounts/admin-user-kubernetes-dashboard.txt`.

### Helm Chart Operations

**Always run in this order** — subcharts use `file://` references that must be resolved first:
```bash
./build.sh helm-build    # 1. Update subchart dependencies (REQUIRED before lint/package)
./build.sh helm-verify   # 2. Lint + template render (run before pushing changes)
./build.sh helm-package  # 3. Package to helm-charts/packages/
```

Individual targets:
```bash
./build.sh helm-lint        # Lint all Helm charts
./build.sh helm-template    # Render templates for review (includes global naming tests)
./build.sh helm-test        # Run Helm tests against a live release
```

## Architecture

### Stack
- **kind** — local Kubernetes cluster runtime (cluster name: `my-local-cluster`)
- **Istio** v1.23.2 — service mesh; demo profile; sidecar injection enabled in `default` namespace
- **ArgoCD** — GitOps CD; admin password auto-saved to `credentials/`
- **Argo Rollouts** v1.7.2 — canary/blue-green deployments; integrates with Istio for traffic splitting
- **Kargo** v1.8.4 — multi-stage promotion pipeline (Warehouse → Stages); integrates with ArgoCD
- **cert-manager** v1.14.0 — SSL certificates (self-signed for local, Let's Encrypt for prod)
- **OpenTelemetry Operator** — manages `OpenTelemetryCollector` and `Instrumentation` CRs; requires cert-manager
- **Kubernetes Dashboard** — web UI; token auto-saved to `credentials/`

### Namespace Organization
| Namespace | Component |
|---|---|
| `istio-system` | Istio control plane |
| `argocd` | ArgoCD |
| `argo-rollouts` | Argo Rollouts controller |
| `kargo` | Kargo |
| `kubernetes-dashboard` | Dashboard |
| `cert-manager` | cert-manager |
| `opentelemetry-operator` | OpenTelemetry Operator |
| `default` | App workloads (Istio sidecar injection enabled) |

### Helm Chart Architecture

`helm-charts/app-template` (v2.0.0) is the primary chart. It renders a standard `Deployment` by default, or an Argo Rollouts `Rollout` when `argo-rollouts.enabled: true`. Core templates: `deployment.yaml`, `service.yaml`, `serviceaccount.yaml`, `hpa.yaml`.

Three optional subcharts in `app-template/charts/`:

| Subchart toggle key | Subchart | What it adds |
|---|---|---|
| `argo-rollouts.enabled: true` | `charts/argo-rollouts/` | `Rollout` object, `AnalysisTemplate` |
| `istio-routing.enabled: true` | `charts/istio-routing/` | `VirtualService`, `DestinationRule` |
| `kargo-config.enabled: true` | `charts/kargo-config/` | `Warehouse`, `Stage`, `PromotionTask` |

HPA is suppressed when `argo-rollouts.enabled: true` (Rollout manages scaling).

All template helpers use prefix `app-template.*` (defined in `templates/_helpers.tpl`). Always use `{{ include "app-template.fullname" . }}` for naming — never hardcode release or chart names.

#### Global Naming Convention
When `global.environment` and `global.region` are set, resource names follow:
- With flavor: `<service>-<env>-<flavor>-<region>` (e.g. `service-staging-qa1-us-west-2`)
- Without flavor: `<service>-<env>-<region>` (e.g. `service-prod-us-west-2`)

Leave `global.environment` and `global.region` empty to fall back to standard Helm release-name logic. `fullnameOverride` always takes highest priority.

### Infrastructure Routing
After running `setup-infrastructure.sh`, tools are accessible via the Istio IngressGateway using path-based routing: ArgoCD at `/argocd`, Kargo at `/kargo`, Dashboard at `/dashboard`, Rollouts at `/rollouts`. See [manifests/infrastructure/tools-routing.yaml](manifests/infrastructure/tools-routing.yaml).

## CI/CD

GitHub Actions ([`.github/workflows/helm-ci.yml`](.github/workflows/helm-ci.yml)) triggers on changes to `helm-charts/` or `deployments/`:
1. **Lint & Test** — Helm lint + template rendering for multiple scenarios + package
2. **Integration Test** — Deploys to a temporary kind cluster with Istio and Argo Rollouts CRDs
3. **Security Scan** — Trivy scan on helm-charts directory, results uploaded to GitHub Security tab

Always run `./build.sh helm-verify` locally before pushing changes to `helm-charts/` or `deployments/`.

## Key Conventions

### Scripts
- `scripts/windows/` is the source of truth for automation; `scripts/linux/` must mirror every script
- Every `install-*.ps1`/`.sh` must be idempotent: check if the component namespace exists and exit early if so
- Namespace creation must always use `kubectl create namespace <ns> --dry-run=client -o yaml | kubectl apply -f -` (never bare `kubectl create namespace`)
- Credentials go to `credentials/`, binaries/plugins go to `tools/` — both are git-ignored

### Manifests
- ArgoCD `Application` resources must be in namespace `argocd` and include the `resources-finalizer.argocd.argoproj.io` finalizer
- Never set `syncPolicy.automated` on an app that Kargo also manages — Kargo controls the sync trigger
- Kargo uses the **PromotionTask** API (`promotionTemplate.spec.steps`); never use the deprecated `promotionMechanisms` API
- Kargo: Project, Warehouse, and all Stages share the same namespace (= the project name); the `Project` resource is cluster-scoped (no namespace)
- Warehouse image subscriptions must use a semver constraint (e.g. `^1.0.0`), never `latest`
- Freight chain: `dev` stage uses `sources.direct: true`; `staging` pulls from `dev`; `prod` pulls from `staging`

### Helm Charts
- Run `./build.sh helm-build` before `helm lint` or `helm package` — subcharts are referenced via `file://` and must be resolved first
- Labels follow `app.kubernetes.io/*` standard as defined in `app-template.labels` and `app-template.selectorLabels`
- The packaged chart goes to `helm-charts/packages/`

## Troubleshooting

**Force reinstall a component (macOS/Linux):**
```bash
bash scripts/linux/uninstall-all.sh --force
bash scripts/linux/install-all.sh --non-interactive
```

**Pod not ready after install** (install scripts wait 300s):
```bash
kubectl get pods -n <namespace> -w
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

**Port-forward fails:**
```bash
kubectl cluster-info              # verify cluster connectivity
kubectl get svc -n <namespace>
lsof -i :<port>                   # check port in use (macOS/Linux)
netstat -ano | findstr :<port>    # check port in use (Windows)
```
