#!/usr/bin/env pwsh
# Install Argo Rollouts on the kind cluster

param(
    [string]$Version = "v1.7.2"
)

Write-Host "Installing Argo Rollouts $Version..." -ForegroundColor Cyan

# Check if Argo Rollouts is already installed
$rolloutsNamespace = kubectl get namespace argo-rollouts --ignore-not-found=true 2>$null
if ($rolloutsNamespace) {
    Write-Host "✓ Argo Rollouts is already installed" -ForegroundColor Green
    
    # Check if controller is running
    $rolloutsPod = kubectl get deployment argo-rollouts -n argo-rollouts --ignore-not-found=true 2>$null
    if ($rolloutsPod) {
        $status = kubectl get deployment argo-rollouts -n argo-rollouts -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>$null
        if ($status -eq "True") {
            Write-Host "  Controller is running" -ForegroundColor Green
        } else {
            Write-Host "  WARNING: Controller exists but may not be ready" -ForegroundColor Yellow
        }
        kubectl get pods -n argo-rollouts
    }
    
    # Check for kubectl plugin
    if (Test-Path ".\tools\kubectl-plugins\kubectl-argo-rollouts.exe") {
        Write-Host "  kubectl plugin: installed" -ForegroundColor Green
    } else {
        Write-Host "  kubectl plugin: not found, downloading..." -ForegroundColor Yellow
        $pluginUrl = "https://github.com/argoproj/argo-rollouts/releases/download/$Version/kubectl-argo-rollouts-windows-amd64"
        New-Item -ItemType Directory -Force -Path ".\tools\kubectl-plugins" | Out-Null
        Invoke-WebRequest -Uri $pluginUrl -OutFile ".\tools\kubectl-plugins\kubectl-argo-rollouts.exe"
        Write-Host "  Plugin downloaded" -ForegroundColor Green
    }
    
    Write-Host "
  To access dashboard:" -ForegroundColor Yellow
    Write-Host "    .\tools\kubectl-plugins\kubectl-argo-rollouts.exe dashboard" -ForegroundColor White
    exit 0
}

# Create namespace
Write-Host "Creating argo-rollouts namespace..." -ForegroundColor Yellow
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -

# Install Argo Rollouts
Write-Host "Installing Argo Rollouts components..." -ForegroundColor Yellow
kubectl apply -n argo-rollouts -f "https://github.com/argoproj/argo-rollouts/releases/download/$Version/install.yaml"

# Wait for rollouts controller to be ready
Write-Host "Waiting for Argo Rollouts controller to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=Available deployment/argo-rollouts -n argo-rollouts --timeout=180s

# Download kubectl plugin if not present
$pluginDir = "$env:USERPROFILE\.krew\bin"
if (-not (Test-Path "$pluginDir\kubectl-argo-rollouts.exe")) {
    Write-Host "`nDownloading kubectl argo-rollouts plugin..." -ForegroundColor Yellow
    $pluginUrl = "https://github.com/argoproj/argo-rollouts/releases/download/$Version/kubectl-argo-rollouts-windows-amd64"
    New-Item -ItemType Directory -Force -Path ".\tools\kubectl-plugins" | Out-Null
    Invoke-WebRequest -Uri $pluginUrl -OutFile ".\tools\kubectl-plugins\kubectl-argo-rollouts.exe"
    Write-Host "Plugin downloaded to: .\tools\kubectl-plugins\kubectl-argo-rollouts.exe" -ForegroundColor Green
    Write-Host "Add this directory to your PATH to use 'kubectl argo rollouts' commands" -ForegroundColor Yellow
}

# Verify installation
Write-Host "`nVerifying Argo Rollouts installation..." -ForegroundColor Yellow
kubectl get pods -n argo-rollouts

Write-Host "`nArgo Rollouts installed successfully!" -ForegroundColor Green
Write-Host "`nTo access Argo Rollouts Dashboard, run:" -ForegroundColor Yellow
Write-Host "  .\tools\kubectl-plugins\kubectl-argo-rollouts.exe dashboard" -ForegroundColor White
