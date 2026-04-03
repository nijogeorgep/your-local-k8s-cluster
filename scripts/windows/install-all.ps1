#!/usr/bin/env pwsh
# Master installation script for all tools

param(
    [switch]$SkipCertManager,
    [switch]$SkipIstio,
    [switch]$SkipArgoCD,
    [switch]$SkipArgoRollouts,
    [switch]$SkipKargo,
    [switch]$SkipDashboard,
    [switch]$NonInteractive
)

$ErrorActionPreference = "Stop"
$Interactive = -not $NonInteractive

Write-Host @"
╔═══════════════════════════════════════════════╗
║   Local Kubernetes Cluster Setup             ║
║   Installing: cert-manager, Istio, ArgoCD,   ║
║              Argo Rollouts, Kargo, Dashboard  ║
╚═══════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Verify prerequisites
Write-Host "`nVerifying prerequisites..." -ForegroundColor Yellow

# Check kubectl
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: kubectl not found in PATH" -ForegroundColor Red
    exit 1
}

# Check helm (required for Kargo)
if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
    Write-Host "WARNING: helm not found in PATH. Kargo installation will fail." -ForegroundColor Yellow
    if ($Interactive) {
        $continue = Read-Host "Continue anyway? (y/n)"
        if ($continue -ne 'y') { exit 1 }
    }
}

# Check cluster connectivity
try {
    kubectl cluster-info | Out-Null
    Write-Host "✓ Cluster is accessible" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Cannot connect to Kubernetes cluster" -ForegroundColor Red
    exit 1
}

# Installation sequence
$tools = @()
if (-not $SkipCertManager) { $tools += @{Name="cert-manager"; Script=".\scripts\install-cert-manager.ps1"} }
if (-not $SkipIstio) { $tools += @{Name="Istio"; Script=".\scripts\install-istio.ps1"} }
if (-not $SkipArgoCD) { $tools += @{Name="ArgoCD"; Script=".\scripts\install-argocd.ps1"} }
if (-not $SkipArgoRollouts) { $tools += @{Name="Argo Rollouts"; Script=".\scripts\install-argo-rollouts.ps1"} }
if (-not $SkipKargo) { $tools += @{Name="Kargo"; Script=".\scripts\install-kargo.ps1"} }
if (-not $SkipDashboard) { $tools += @{Name="Kubernetes Dashboard"; Script=".\scripts\install-dashboard.ps1"} }

$totalTools = $tools.Count
$current = 0

foreach ($tool in $tools) {
    $current++
    Write-Host "`n[$current/$totalTools] Installing $($tool.Name)..." -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
    
    if ($Interactive) {
        $response = Read-Host "Proceed with $($tool.Name) installation? (y/n/q)"
        if ($response -eq 'q') {
            Write-Host "Installation cancelled by user." -ForegroundColor Yellow
            exit 0
        }
        if ($response -ne 'y') {
            Write-Host "Skipping $($tool.Name)..." -ForegroundColor Yellow
            continue
        }
    }
    
    try {
        & $tool.Script
        Write-Host "`n✓ $($tool.Name) installation completed" -ForegroundColor Green
    } catch {
        Write-Host "`n✗ $($tool.Name) installation failed: $_" -ForegroundColor Red
        if ($Interactive) {
            $continue = Read-Host "Continue with remaining installations? (y/n)"
            if ($continue -ne 'y') { exit 1 }
        } else {
            exit 1
        }
    }
    
    Start-Sleep -Seconds 2
}

Write-Host @"

╔═══════════════════════════════════════════════╗
║   Installation Complete!                      ║
╚═══════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "Installed components:" -ForegroundColor Cyan
kubectl get pods -A | Select-String "istio|argo|kargo"

Write-Host "`nDashboard:    kubectl proxy (then use token from credentials/dashboard-token.txt)" -ForegroundColor White
Write-Host "  ArgoCD UI:    kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor White
Write-Host "  Kargo UI:     kubectl port-forward svc/kargo-api -n kargo 8081:80" -ForegroundColor White
Write-Host "  Rollouts UI:  .\tools\kubectl-plugins\kubectl-argo-rollouts.exe dashboard" -ForegroundColor White

if (Test-Path ".\credentials\argocd-credentials.txt") {
    Write-Host "`nArgoCD credentials: .\credentials\argocd-credentials.txt" -ForegroundColor Cyan
}
if (Test-Path ".\credentials\dashboard-token.txt") {
    Write-Host "Dashboard token: .\credentials\dashboard-token.txt" -ForegroundColor Cyan
}
