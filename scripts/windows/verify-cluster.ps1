#!/usr/bin/env pwsh
# Verify cluster status and installed components

Write-Host "Kubernetes Cluster Status" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════`n" -ForegroundColor Cyan

# Cluster info
Write-Host "Cluster Information:" -ForegroundColor Yellow
kubectl cluster-info
Write-Host ""

# Node status
Write-Host "Nodes:" -ForegroundColor Yellow
kubectl get nodes -o wide
Write-Host ""

# Check installed components
Write-Host "Installed Components:" -ForegroundColor Yellow

$namespaces = kubectl get namespaces -o json | ConvertFrom-Json
$installedComponents = @()

if ($namespaces.items.metadata.name -contains "cert-manager") {
    $installedComponents += "✓ cert-manager"
    Write-Host "  ✓ cert-manager" -ForegroundColor Green
    kubectl get pods -n cert-manager
    Write-Host ""
}

if ($namespaces.items.metadata.name -contains "istio-system") {
    $installedComponents += "✓ Istio"
    $istioVersion = kubectl get deployment -n istio-system istiod -o jsonpath='{.spec.template.spec.containers[0].image}' 2>$null
    Write-Host "  ✓ Istio: $istioVersion" -ForegroundColor Green
    kubectl get pods -n istio-system
    Write-Host ""
}

if ($namespaces.items.metadata.name -contains "argocd") {
    $installedComponents += "✓ ArgoCD"
    Write-Host "  ✓ ArgoCD" -ForegroundColor Green
    kubectl get pods -n argocd
    Write-Host ""
}

if ($namespaces.items.metadata.name -contains "argo-rollouts") {
    $installedComponents += "✓ Argo Rollouts"
    Write-Host "  ✓ Argo Rollouts" -ForegroundColor Green
    kubectl get pods -n argo-rollouts
    Write-Host ""
}

if ($namespaces.items.metadata.name -contains "kargo") {
    $installedComponents += "✓ Kargo"
    Write-Host "  ✓ Kargo" -ForegroundColor Green
    kubectl get pods -n kargo
    Write-Host ""
}

if ($namespaces.items.metadata.name -contains "kubernetes-dashboard") {
    $installedComponents += "✓ Kubernetes Dashboard"
    Write-Host "  ✓ Kubernetes Dashboard" -ForegroundColor Green
    kubectl get pods -n kubernetes-dashboard
    Write-Host ""
}

if ($installedComponents.Count -eq 0) {
    Write-Host "  No additional components installed yet." -ForegroundColor Yellow
    Write-Host "  Run .\scripts\install-all.ps1 to install tools." -ForegroundColor Cyan
}

Write-Host "`nResource Usage:" -ForegroundColor Yellow
kubectl top nodes 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  (Metrics server not installed)" -ForegroundColor DarkGray
}
