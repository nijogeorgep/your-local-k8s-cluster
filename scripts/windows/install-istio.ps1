#!/usr/bin/env pwsh
# Install Istio on the kind cluster

param(
    [string]$IstioVersion = "1.23.2"
)

Write-Host "Installing Istio $IstioVersion..." -ForegroundColor Cyan

# Check if Istio is already installed
$istioNamespace = kubectl get namespace istio-system --ignore-not-found=true 2>$null
if ($istioNamespace) {
    Write-Host "✓ Istio is already installed" -ForegroundColor Green
    
    # Check if it's running
    $istiodPod = kubectl get pods -n istio-system -l app=istiod --field-selector=status.phase=Running --ignore-not-found=true 2>$null
    if ($istiodPod) {
        Write-Host "  Istiod is running" -ForegroundColor Green
        $istioVersion = kubectl get deployment -n istio-system istiod -o jsonpath='{.spec.template.spec.containers[0].image}' 2>$null
        Write-Host "  Version: $istioVersion" -ForegroundColor Cyan
    } else {
        Write-Host "  WARNING: Istio namespace exists but pods are not running" -ForegroundColor Yellow
    }
    
    # Verify sidecar injection on default namespace
    $injectionLabel = kubectl get namespace default -o jsonpath='{.metadata.labels.istio-injection}' 2>$null
    if ($injectionLabel -eq "enabled") {
        Write-Host "  Sidecar injection: enabled on default namespace" -ForegroundColor Green
    } else {
        Write-Host "  Enabling sidecar injection for default namespace..." -ForegroundColor Yellow
        kubectl label namespace default istio-injection=enabled --overwrite
    }
    
    kubectl get pods -n istio-system
    exit 0
}

# Download istioctl if not present
$istioDir = ".\tools\istio-$IstioVersion"
if (-not (Test-Path $istioDir)) {
    Write-Host "Downloading Istio..." -ForegroundColor Yellow
    $downloadUrl = "https://github.com/istio/istio/releases/download/$IstioVersion/istio-$IstioVersion-win.zip"
    $zipFile = ".\tools\istio-$IstioVersion.zip"
    
    New-Item -ItemType Directory -Force -Path ".\tools" | Out-Null
    Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile
    Expand-Archive -Path $zipFile -DestinationPath ".\tools" -Force
    Remove-Item $zipFile
}

$istioctl = "$istioDir\bin\istioctl.exe"

# Install Istio with default profile
Write-Host "Installing Istio to cluster..." -ForegroundColor Yellow
& $istioctl install --set profile=demo -y

# Label default namespace for sidecar injection
Write-Host "Enabling sidecar injection for default namespace..." -ForegroundColor Yellow
kubectl label namespace default istio-injection=enabled --overwrite

# Verify installation
Write-Host "`nVerifying Istio installation..." -ForegroundColor Yellow
kubectl get pods -n istio-system

Write-Host "`nIstio installed successfully!" -ForegroundColor Green
Write-Host "istioctl available at: $istioctl" -ForegroundColor Green
