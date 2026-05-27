---
description: "Generate a Helm values file and deployment manifests to deploy a new app using the app-template chart. Prompts for image, port, and which subcharts to enable (Argo Rollouts, Istio, Kargo)."
argument-hint: "App name (e.g. my-api)"
agent: agent
tools: [create_file, read_file]
---

You are helping the user deploy a new application onto this local Kubernetes cluster using the `app-template` Helm chart.

Reference files you should use as templates:
- [values-examples.yaml](../../helm-charts/app-template/values-examples.yaml) — full example values for each subchart combination
- [values-spring-kotlin-app.yaml](../../deployments/spring-kotlin-app/values-spring-kotlin-app.yaml) — real-world reference with all three subcharts enabled
- [argocd-application.yaml](../../manifests/examples/argocd-application.yaml) — ArgoCD Application template
- [kargo-project.yaml](../../manifests/examples/kargo-project.yaml) — Kargo Project/Warehouse/Stage template
- [helm-charts/app-template/values.yaml](../../helm-charts/app-template/values.yaml) — full defaults with comments

## Step 1 — Collect Inputs

Ask the user for the following (all at once, as a numbered list):

1. **App name** — used as the Helm release name and file prefix (e.g. `my-api`)
2. **Container image** — repository and tag (e.g. `ghcr.io/myorg/my-api:v1.0.0`)
3. **Container port** — the port the app listens on (e.g. `8080`)
4. **Subcharts to enable** — which optional features they want:
   - **Argo Rollouts** — canary/blue-green progressive delivery (uses `Rollout` instead of `Deployment`)?
   - **Istio routing** — VirtualService + DestinationRule for path-based ingress and traffic splitting?
   - **Kargo** — multi-stage promotion pipeline (dev → staging → prod)?
5. **If Argo Rollouts**: canary strategy steps (accept defaults or customise)?
6. **If Istio**: ingress path prefix (e.g. `/my-api`)?
7. **If Kargo**: Git repo URL for ArgoCD/Kargo to watch?
8. **ArgoCD Application manifest** — generate one? (yes/no)

## Step 2 — Generate Files

Based on the answers, create **all** of the following that apply:

### Always: `deployments/<app-name>/values-<app-name>.yaml`

Build the values file from the collected inputs:
- Set `image.repository`, `image.tag`, `service.targetPort`
- Enable only the subcharts the user requested; explicitly set `enabled: false` for the rest
- If **Argo Rollouts** enabled: add a `canary` strategy with sensible default steps (10% → pause 2m → 25% → pause 2m → 50% → pause 5m → 100%) unless the user supplied custom steps
- If **Istio** enabled: set `istio-routing.ingress.path` to the user's path prefix; enable `trafficRouting` only if Argo Rollouts is also enabled
- If **Kargo** enabled: populate `kargo-config` with Project name, Warehouse image subscription pointing at the user's image repo, and three stages (dev/staging/prod) wired to ArgoCD app updates
- Add a comment block at the top: app name, image, enabled subcharts, and the deploy command

### If ArgoCD requested: `manifests/examples/<app-name>-argocd.yaml`

Generate an ArgoCD `Application` resource pointing to `helm-charts/app-template` with the values inlined.

## Step 3 — Show Deploy Commands

After creating the files, print the exact commands to deploy:

```powershell
# Verify the chart renders correctly first
helm template <app-name> ./helm-charts/app-template -f deployments/<app-name>/values-<app-name>.yaml

# Deploy with Helm
helm install <app-name> ./helm-charts/app-template \
  -f deployments/<app-name>/values-<app-name>.yaml \
  --namespace default

# OR — apply the ArgoCD Application (GitOps)
kubectl apply -f manifests/examples/<app-name>-argocd.yaml
```

Also remind the user to run `make helm-build` first if they haven't already.
