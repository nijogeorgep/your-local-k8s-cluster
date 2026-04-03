#!/usr/bin/env pwsh
# Install cert-manager on the kind cluster
# cert-manager is required by Kargo and other tools for certificate management

param(
    [string]$Version = "v1.14.0"
)

Write-Host "Installing cert-manager $Version..." -ForegroundColor Cyan

# Check if cert-manager is already installed
$certManagerNamespace = kubectl get namespace cert-manager --ignore-not-found=true 2>$null
if ($certManagerNamespace) {
    Write-Host "✓ cert-manager is already installed" -ForegroundColor Green
    
    # Check if pods are running
    $certManagerPods = kubectl get pods -n cert-manager --field-selector=status.phase=Running --ignore-not-found=true 2>$null
    if ($certManagerPods) {
        Write-Host "  Pods are running" -ForegroundColor Green
        kubectl get pods -n cert-manager
    } else {
        Write-Host "  WARNING: cert-manager namespace exists but pods may not be running" -ForegroundColor Yellow
        kubectl get pods -n cert-manager
    }
    
    exit 0
}

# Install cert-manager
Write-Host "Applying cert-manager manifests..." -ForegroundColor Yellow
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/$Version/cert-manager.yaml"

# Wait for cert-manager to be ready
Write-Host "`nWaiting for cert-manager pods to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10  # Give pods time to start creating
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=300s

# Verify installation
Write-Host "`nVerifying cert-manager installation..." -ForegroundColor Yellow
kubectl get pods -n cert-manager

Write-Host "`ncert-manager installed successfully!" -ForegroundColor Green
Write-Host "`ncert-manager provides certificate management for the cluster." -ForegroundColor Cyan
Write-Host "It's required by Kargo and other tools that use TLS certificates." -ForegroundColor Cyan
