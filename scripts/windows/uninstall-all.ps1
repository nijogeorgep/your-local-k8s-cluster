#!/usr/bin/env pwsh
# Uninstall all tools from the cluster

param(
    [switch]$Force
)

Write-Host "Uninstalling all tools from the cluster..." -ForegroundColor Yellow

if (-not $Force) {
    $confirm = Read-Host "This will remove Istio, ArgoCD, Argo Rollouts, and Kargo. Continue? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "Uninstallation cancelled." -ForegroundColor Cyan
        exit 0
    }
}

# Uninstall Dashboard
Write-Host "`nUninstalling Kubernetes Dashboard..." -ForegroundColor Yellow
kubectl delete namespace kubernetes-dashboard 2>$null
kubectl delete clusterrolebinding admin-user 2>$null

# Uninstall Kargo
Write-Host "Uninstalling Kargo..." -ForegroundColor Yellow
helm uninstall kargo -n kargo 2>$null
kubectl delete namespace kargo 2>$null

# Uninstall Argo Rollouts
Write-Host "Uninstalling Argo Rollouts..." -ForegroundColor Yellow
kubectl delete namespace argo-rollouts 2>$null

# Uninstall ArgoCD
Write-Host "Uninstalling ArgoCD..." -ForegroundColor Yellow
kubectl delete namespace argocd 2>$null

# Uninstall Istio
Write-Host "Uninstalling Istio..." -ForegroundColor Yellow
$istioctl = Get-ChildItem -Path ".\tools" -Filter "istioctl.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($istioctl) {
    & $istioctl.FullName uninstall --purge -y 2>$null
}
kubectl delete namespace istio-system 2>$null

Write-Host "`nAll tools uninstalled successfully!" -ForegroundColor Green
