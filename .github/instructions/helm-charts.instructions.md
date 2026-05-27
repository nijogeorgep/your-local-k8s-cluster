---
description: "Use when working on Helm charts, values files, chart templates, subcharts, or running helm-lint/template/package. Covers app-template chart structure, subchart conventions, and CI workflow."
applyTo: "helm-charts/**"
---

# Helm Chart Conventions

Primary chart: `helm-charts/app-template` (v2.0.0). See [helm-charts/ARCHITECTURE.md](../../helm-charts/ARCHITECTURE.md) for full design rationale.

## Workflow — Always Run in This Order
```bash
make helm-build    # 1. Update local file:// subchart dependencies (REQUIRED first)
make helm-verify   # 2. Lint + template render all scenarios
make helm-package  # 3. Package to helm-charts/packages/
```
Skipping `helm-build` causes lint/template failures because subcharts use `file://` references.

## Subchart Toggles
Each subchart is independently disabled by default; enable via values:
| Value key | Subchart | What it adds |
|-----------|----------|--------------|
| `argo-rollouts.enabled: true` | `charts/argo-rollouts/` | `Rollout` object, `AnalysisTemplate` |
| `istio-routing.enabled: true` | `charts/istio-routing/` | `VirtualService`, `DestinationRule` |
| `kargo-config.enabled: true` | `charts/kargo-config/` | `Warehouse`, `Stage`, `PromotionTask` |

When `argo-rollouts.enabled` is `false`, the chart renders a standard `Deployment` + optional `HPA`. When `true`, HPA is suppressed (Rollout manages scaling).

## Key Template Conventions
- All helpers are in `templates/_helpers.tpl` using prefix `app-template.*`
- Use `{{ include "app-template.fullname" . }}` for naming; never hardcode release/chart names
- Labels follow `app.kubernetes.io/*` standard (defined in `app-template.labels` and `app-template.selectorLabels`)

## values.yaml Patterns
- `image.repository` / `image.tag` — top-level image config
- `service.port` / `service.targetPort` — ClusterIP service (default port 80)
- `autoscaling.enabled` — HPA (only applies when `argo-rollouts.enabled: false`)
- See [helm-charts/app-template/values-examples.yaml](../../helm-charts/app-template/values-examples.yaml) for complete usage examples

## CI — What Triggers Helm CI
`.github/workflows/helm-ci.yml` runs on changes to `helm-charts/**` or `deployments/**`:
1. Lint + template render (multiple value scenarios)
2. Integration test on a temporary kind cluster with Istio and Argo Rollouts CRDs pre-installed
3. Trivy security scan → GitHub Security tab

Always run `make helm-verify` locally before pushing changes to these paths.
