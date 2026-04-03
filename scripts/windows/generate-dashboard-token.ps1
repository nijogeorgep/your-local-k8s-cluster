#!/usr/bin/env pwsh
# Generate a new token for Kubernetes Dashboard access

param(
    [string]$ServiceAccount = "admin-user",
    [string]$Namespace = "kubernetes-dashboard"
)

Write-Host "Generating token for service account '$ServiceAccount' in namespace '$Namespace'..." -ForegroundColor Cyan

# Check if service account exists
$saExists = kubectl get serviceaccount $ServiceAccount -n $Namespace --ignore-not-found=true
if (-not $saExists) {
    Write-Host "ERROR: Service account '$ServiceAccount' not found in namespace '$Namespace'" -ForegroundColor Red
    Write-Host "Run .\scripts\install-dashboard.ps1 first to create the dashboard and service account" -ForegroundColor Yellow
    exit 1
}

# Check if secret exists
$secretExists = kubectl get secret "$ServiceAccount-token" -n $Namespace --ignore-not-found=true 2>$null
if (-not $secretExists) {
    Write-Host "Token secret not found. Creating new secret..." -ForegroundColor Yellow
    
    $secretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: $ServiceAccount-token
  namespace: $Namespace
  annotations:
    kubernetes.io/service-account.name: $ServiceAccount
type: kubernetes.io/service-account-token
"@
    
    $secretYaml | kubectl apply -f -
    Start-Sleep -Seconds 3
}

# Get the token
$token = kubectl get secret "$ServiceAccount-token" -n $Namespace -o jsonpath="{.data.token}" 2>$null
if (-not $token) {
    # For Kubernetes 1.24+, create a temporary token
    Write-Host "Using kubectl create token (Kubernetes 1.24+)..." -ForegroundColor Yellow
    $token = kubectl create token $ServiceAccount -n $Namespace --duration=87600h
    $tokenDecoded = $token
} else {
    $tokenDecoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token))
}

Write-Host "`nAccess Token for '$ServiceAccount':" -ForegroundColor Green
Write-Host $tokenDecoded -ForegroundColor White

Write-Host "`nToken copied to clipboard (if available)" -ForegroundColor Cyan
try {
    $tokenDecoded | Set-Clipboard
    Write-Host "✓ Token copied to clipboard" -ForegroundColor Green
} catch {
    Write-Host "! Clipboard not available" -ForegroundColor Yellow
}

# Save to file
$credsFile = ".\credentials\dashboard-token.txt"
New-Item -ItemType Directory -Force -Path ".\credentials" | Out-Null
@"
Kubernetes Dashboard Access Token
==================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Service Account: $ServiceAccount
Namespace: $Namespace

Token:
$tokenDecoded

Access Methods:
---------------
Method 1 - kubectl proxy:
  kubectl proxy
  URL: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

Method 2 - Port-forward:
  kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443
  URL: https://localhost:8443

Authentication:
  Select 'Token' and paste the token above
"@ | Out-File -FilePath $credsFile -Encoding UTF8

Write-Host "`nToken saved to: $credsFile" -ForegroundColor Green

Write-Host "`nQuick Access:" -ForegroundColor Yellow
Write-Host "  kubectl proxy" -ForegroundColor White
Write-Host "  Then open: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/" -ForegroundColor Gray
