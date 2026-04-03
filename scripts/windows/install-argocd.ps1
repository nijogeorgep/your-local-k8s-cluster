#!/usr/bin/env pwsh
# Install ArgoCD on the kind cluster

param(
    [string]$Version = "stable"
)

Write-Host "Installing ArgoCD ($Version)..." -ForegroundColor Cyan

# Check if ArgoCD is already installed
$argocdNamespace = kubectl get namespace argocd --ignore-not-found=true 2>$null
if ($argocdNamespace) {
    Write-Host "✓ ArgoCD is already installed" -ForegroundColor Green
    
    # Check if pods are running
    $argocdPods = kubectl get pods -n argocd --field-selector=status.phase=Running --ignore-not-found=true 2>$null
    if ($argocdPods) {
        Write-Host "  ArgoCD pods are running" -ForegroundColor Green
        kubectl get pods -n argocd
    } else {
        Write-Host "  WARNING: ArgoCD namespace exists but pods are not all running" -ForegroundColor Yellow
        kubectl get pods -n argocd
    }
    
    # Get admin password if available
    $passwordSecret = kubectl get secret argocd-initial-admin-secret -n argocd --ignore-not-found=true 2>$null
    if ($passwordSecret) {
        $adminPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
        Write-Host "`n  Username: admin" -ForegroundColor Cyan
        Write-Host "  Password: $adminPassword" -ForegroundColor Cyan
        
        # Update credentials file
        $credsFile = ".\credentials\argocd-credentials.txt"
        if (-not (Test-Path $credsFile)) {
            New-Item -ItemType Directory -Force -Path ".\credentials" | Out-Null
            @"
ArgoCD Credentials
==================
URL: https://localhost:8080 (after port-forward)
Username: admin
Password: $adminPassword

Port-forward command:
kubectl port-forward svc/argocd-server -n argocd 8080:443
"@ | Out-File -FilePath $credsFile -Encoding UTF8
            Write-Host "`n  Credentials saved to: $credsFile" -ForegroundColor Green
        }
    }
    
    Write-Host "
  To access ArgoCD UI:" -ForegroundColor Yellow
    Write-Host "    kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor White
    exit 0
}

# Create namespace
Write-Host "Creating argocd namespace..." -ForegroundColor Yellow
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
Write-Host "Installing ArgoCD components..." -ForegroundColor Yellow
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/$Version/manifests/install.yaml"

# Wait for ArgoCD to be ready
Write-Host "Waiting for ArgoCD pods to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get initial admin password
Write-Host "`nRetrieving initial admin password..." -ForegroundColor Yellow
$adminPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host "`nArgoCD installed successfully!" -ForegroundColor Green
Write-Host "Username: admin" -ForegroundColor Cyan
Write-Host "Password: $adminPassword" -ForegroundColor Cyan
Write-Host "`nTo access ArgoCD UI, run:" -ForegroundColor Yellow
Write-Host "  kubectl port-forward svc/argocd-server -n argocd 8080:443" -ForegroundColor White
Write-Host "  Then navigate to: https://localhost:8080" -ForegroundColor White

# Save credentials to file
$credsFile = ".\credentials\argocd-credentials.txt"
New-Item -ItemType Directory -Force -Path ".\credentials" | Out-Null
@"
ArgoCD Credentials
==================
URL: https://localhost:8080 (after port-forward)
Username: admin
Password: $adminPassword

Port-forward command:
kubectl port-forward svc/argocd-server -n argocd 8080:443
"@ | Out-File -FilePath $credsFile -Encoding UTF8

Write-Host "`nCredentials saved to: $credsFile" -ForegroundColor Green
