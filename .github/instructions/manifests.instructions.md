---
description: "Use when writing or editing ArgoCD Application, Kargo Project, Warehouse, Stage, or PromotionTask manifests under manifests/. Covers required fields, namespace conventions, sync policies, and the PromotionTask API (not the legacy promotionMechanisms API)."
applyTo: "manifests/**"
---

# Manifest Conventions

Reference examples: [argocd-application.yaml](../examples/argocd-application.yaml) | [kargo-project.yaml](../examples/kargo-project.yaml)

---

## ArgoCD Application

### Required Fields
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <app>-<stage>          # e.g. my-api-dev, my-api-staging
  namespace: argocd            # ALWAYS argocd — never another namespace
  finalizers:
    - resources-finalizer.argocd.argoproj.io  # REQUIRED — prevents orphaned resources on delete
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/<repo>.git
    targetRevision: HEAD
    path: helm-charts/app-template
    helm:
      releaseName: <app>
  destination:
    server: https://kubernetes.default.svc   # local kind cluster — never change this
    namespace: default                        # app workload namespace
```

### Sync Policy Rules
- **GitOps apps** (managed by Kargo or committed to Git): use `automated` with `prune` and `selfHeal`
  ```yaml
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
  ```
- **Tracking-only apps** (Helm-managed, ArgoCD just monitors): omit `automated`, set `CreateNamespace=false`
- Never set `automated` on an app that Kargo also manages — Kargo controls the sync trigger

---

## Kargo Resources

### Namespace Rule
Project, Warehouse, and all Stages share the **same namespace = project name**.
```yaml
# Project itself has no namespace (cluster-scoped)
kind: Project
metadata:
  name: my-app         # → creates namespace "my-app" automatically

# Everything else lives in that namespace
kind: Warehouse
metadata:
  namespace: my-app    # matches project name

kind: Stage
metadata:
  namespace: my-app    # same
```

### Promotion Policy Defaults
```yaml
spec:
  promotionPolicies:
  - stage: dev
    autoPromotionEnabled: true    # dev auto-promotes on new freight
  - stage: staging
    autoPromotionEnabled: false   # staging/prod require manual approval
  - stage: prod
    autoPromotionEnabled: false
```

### Stage — Use `promotionTemplate` (NOT `promotionMechanisms`)
`promotionMechanisms` is **deprecated** as of Kargo v1.8+. Always use `promotionTemplate` with `steps`:

```yaml
# CORRECT — promotionTemplate API
spec:
  promotionTemplate:
    spec:
      steps:
        - uses: argocd-update          # built-in task: sync an ArgoCD Application
          config:
            apps:
              - name: my-app-dev
                namespace: argocd
        - uses: git-commit             # built-in task: commit image tag update to Git
          config:
            path: deployments/my-app
            messageTemplate: "chore: promote {{ .Freight.Image.Tag }} to dev"
```

```yaml
# WRONG — do not use this pattern
spec:
  promotionMechanisms:
    argoCDAppUpdates: [...]
    gitRepoUpdates: [...]
```

### Freight Chain (Stage Sources)
- `dev` stage: `sources.direct: true` (pulls directly from Warehouse)
- `staging` stage: `sources.stages: [dev]` (pulls freight verified by dev)
- `prod` stage: `sources.stages: [staging]`

```yaml
spec:
  requestedFreight:
  - origin:
      kind: Warehouse
      name: my-app
    sources:
      stages: [dev]    # for staging; use direct: true for dev itself
```

### Warehouse Subscriptions
Always pin images to a semver constraint, never `latest`:
```yaml
spec:
  subscriptions:
  - image:
      repoURL: ghcr.io/myorg/my-app
      semverConstraint: ^1.0.0      # NOT "latest"
      discoveryLimit: 5
  - git:
      repoURL: https://github.com/<org>/<repo>.git
      commitSelectionStrategy: NewestFromBranch
      includePaths:
        - helm-charts/app-template/**
```
