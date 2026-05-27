# Copilot Instructions - My Local Cluster

## Project Overview
Local Kubernetes learning environment using **kind** with a full GitOps and service mesh stack. See [CLAUDE.md](../CLAUDE.md) for full architecture, commands, and troubleshooting reference.

## Stack Versions
- Istio v1.23.2 (demo profile) | ArgoCD | Argo Rollouts v1.7.2 | Kargo v1.8.4 | cert-manager v1.14.0

## Critical Path: Script Locations
> **All PowerShell scripts live in `scripts/windows/`** — the Makefile's `install` targets call `./scripts/install-all.ps1` which doesn't exist; run scripts directly from `scripts/windows/` if `make install` fails.

```powershell
.\scripts\windows\install-all.ps1           # Install all (interactive)
.\scripts\windows\install-all.ps1 -NonInteractive
.\scripts\windows\verify-cluster.ps1
.\scripts\windows\setup-infrastructure.ps1  # Apply Istio gateway + cert-manager routing
```

## Common Makefile Commands
```bash
make setup       # create-cluster + install + verify
make verify      # run verify-cluster.ps1
make helm-verify # lint + template render (run before pushing helm changes)
make helm-build  # update chart deps (required before helm-lint/package)
make teardown    # delete cluster + cleanup
```

## Helm Chart
Primary chart: `helm-charts/app-template` (v2.0.0). See [helm-charts/README.md](../helm-charts/README.md) and [ARCHITECTURE.md](../helm-charts/ARCHITECTURE.md).
- Run `make helm-build` before `helm-lint` — chart has local file:// subchart dependencies
- Three optional subcharts toggled by values: `argoRollouts.enabled`, `istioRouting.enabled`, `kargoConfig.enabled`
- CI: `.github/workflows/helm-ci.yml` lints, renders, packages, and Trivy-scans on changes to `helm-charts/` or `deployments/`

## Key Conventions
- `scripts/windows/` — primary source of truth for all automation; `scripts/linux/` mirrors them
- `tools/` and `credentials/` are git-ignored and populated at runtime
- Install scripts are idempotent — skip reinstall if already present; use `uninstall-all.ps1` to force
- Namespace `default` has `istio-injection=enabled`; all pods there get an Envoy sidecar automatically
- Kargo uses the newer **PromotionTask** API (not the legacy Promotion API)
- New namespaces: create with `--dry-run=client -o yaml | kubectl apply -f -` for idempotency

## Reference Docs
- Full commands & troubleshooting: [CLAUDE.md](../CLAUDE.md)
- Helm chart architecture: [helm-charts/ARCHITECTURE.md](../helm-charts/ARCHITECTURE.md)
- Deployment guide: [docs/deployment-guide.md](../docs/deployment-guide.md)
- Dashboard guide: [docs/dashboard-guide.md](../docs/dashboard-guide.md)
- Example app: [deployments/spring-kotlin-app/](../deployments/spring-kotlin-app/)
