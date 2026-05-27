---
description: "Use when writing or editing PowerShell install/uninstall/verify scripts in scripts/windows/, or when creating new component automation scripts. Covers idempotency pattern, credential saving, and namespace creation conventions."
applyTo: "scripts/windows/**"
---

# PowerShell Script Conventions

All automation scripts live in `scripts/windows/` (primary). Bash equivalents in `scripts/linux/` must mirror them. See any existing `install-*.ps1` for a reference implementation.

## Required Script Structure (install-*.ps1)
Every install script must follow this order:

```powershell
# 1. Idempotency check — exit 0 if already installed
$ns = kubectl get namespace <ns> --ignore-not-found=true 2>$null
if ($ns) {
    Write-Host "✓ <Component> is already installed" -ForegroundColor Green
    exit 0
}

# 2. Create namespace (idempotent)
kubectl create namespace <ns> --dry-run=client -o yaml | kubectl apply -f -

# 3. Install (kubectl apply / helm install / istioctl)

# 4. Wait for readiness (300s timeout)
kubectl wait --for=condition=Ready pods --all -n <ns> --timeout=300s

# 5. Save credentials to credentials/ (if applicable)
# credentials/ is git-ignored

# 6. Print port-forward / access instructions
```

## Key Rules
- **Never use `kubectl create namespace` without `--dry-run=client -o yaml | kubectl apply -f -`** — it errors if the namespace exists
- **Tools go to `tools/`**, credentials go to `credentials/` — both are git-ignored
- **`-NonInteractive` flag**: `install-all.ps1` accepts this for CI; individual scripts must also support silent execution
- Use `Write-Host "✓ ..."  -ForegroundColor Green` for success, `Write-Host "✗ ..." -ForegroundColor Red` for errors
- Kargo installs via `helm`; all others use `kubectl apply` or tool-specific CLIs (`istioctl`, `helm`)

## Namespace Reference
| Namespace | Component |
|-----------|-----------|
| `istio-system` | Istio control plane |
| `argocd` | ArgoCD |
| `argo-rollouts` | Argo Rollouts controller |
| `kargo` | Kargo |
| `kubernetes-dashboard` | Dashboard |
| `cert-manager` | cert-manager |
| `default` | App workloads (sidecar injection enabled) |
