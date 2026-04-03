#!/usr/bin/env pwsh
# Install Kubernetes Dashboard

param(
    [string]$Version = "v2.7.0"
)

Write-Host "Installing Kubernetes Dashboard $Version..." -ForegroundColor Cyan

# Check if Dashboard is already installed
$dashboardNamespace = kubectl get namespace kubernetes-dashboard --ignore-not-found=true 2>$null
if ($dashboardNamespace) {
    Write-Host "✓ Kubernetes Dashboard is already installed" -ForegroundColor Green
    
    # Check if pods are running
    $dashboardPod = kubectl get deployment kubernetes-dashboard -n kubernetes-dashboard --ignore-not-found=true 2>$null
    if ($dashboardPod) {
        $status = kubectl get deployment kubernetes-dashboard -n kubernetes-dashboard -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>$null
        if ($status -eq "True") {
            Write-Host "  Dashboard is running" -ForegroundColor Green
        } else {
            Write-Host "  WARNING: Dashboard exists but may not be ready" -ForegroundColor Yellow
        }
        kubectl get pods -n kubernetes-dashboard
    }
    
    # Check if admin service account exists
    $adminSA = kubectl get serviceaccount admin-user -n kubernetes-dashboard --ignore-not-found=true 2>$null
    if ($adminSA) {
        Write-Host "  Admin service account: exists" -ForegroundColor Green
        
        # Try to get existing token
        $tokenSecret = kubectl get secret admin-user-token -n kubernetes-dashboard --ignore-not-found=true 2>$null
        if ($tokenSecret) {
            $token = kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath="{.data.token}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
            Write-Host "
  Access Token:" -ForegroundColor Cyan
            Write-Host "  $token" -ForegroundColor White
            
            # Update token file
            $credsFile = ".\credentials\dashboard-token.txt"
            if (-not (Test-Path $credsFile)) {
                New-Item -ItemType Directory -Force -Path ".\credentials" | Out-Null
                @"
Kubernetes Dashboard Access Token
==================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Service Account: admin-user
Namespace: kubernetes-dashboard

Token:
$token

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
                Write-Host "
  Token saved to: $credsFile" -ForegroundColor Green
            }
        } else {
            Write-Host "  Admin token: not found, you can regenerate with:" -ForegroundColor Yellow
            Write-Host "    .\scripts\generate-dashboard-token.ps1" -ForegroundColor White
        }
    } else {
        Write-Host "  Admin service account: not found" -ForegroundColor Yellow
        Write-Host "  Creating admin service account..." -ForegroundColor Yellow
        
        # Create the service account and token
        $dashboardAdminYaml = @"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
"@
        $dashboardAdminYaml | kubectl apply -f -
        Start-Sleep -Seconds 3
        
        $token = kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath="{.data.token}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
        Write-Host "
  Admin service account created" -ForegroundColor Green
        Write-Host "  Token: $token" -ForegroundColor Cyan
    }
    
    Write-Host "
  To access Dashboard:" -ForegroundColor Yellow
    Write-Host "    kubectl proxy" -ForegroundColor White
    Write-Host "    URL: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/" -ForegroundColor Gray
    exit 0
}

# Install Kubernetes Dashboard
Write-Host "Installing Kubernetes Dashboard components..." -ForegroundColor Yellow
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/dashboard/$Version/aio/deploy/recommended.yaml"

# Wait for dashboard to be ready
Write-Host "Waiting for dashboard pods to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=Ready pods --all -n kubernetes-dashboard --timeout=180s

# Create service account and cluster role binding
Write-Host "`nCreating dashboard admin service account..." -ForegroundColor Yellow

$dashboardAdminYaml = @"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
"@

$dashboardAdminYaml | kubectl apply -f -

# Wait a moment for the token to be generated
Write-Host "Waiting for token generation..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Get the token
Write-Host "`nRetrieving access token..." -ForegroundColor Yellow
$token = kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath="{.data.token}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host "`nKubernetes Dashboard installed successfully!" -ForegroundColor Green
Write-Host "`nAccess Token:" -ForegroundColor Cyan
Write-Host $token -ForegroundColor White

Write-Host "`nTo access the Dashboard:" -ForegroundColor Yellow
Write-Host "  1. Start the proxy:" -ForegroundColor White
Write-Host "     kubectl proxy" -ForegroundColor Gray
Write-Host "`n  2. Navigate to:" -ForegroundColor White
Write-Host "     http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/" -ForegroundColor Gray
Write-Host "`n  3. Select 'Token' authentication and paste the token above" -ForegroundColor White

Write-Host "`nAlternatively, use port-forward:" -ForegroundColor Yellow
Write-Host "  kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443" -ForegroundColor Gray
Write-Host "  Then navigate to: https://localhost:8443" -ForegroundColor Gray

# Save credentials to file
$credsFile = ".\credentials\dashboard-token.txt"
New-Item -ItemType Directory -Force -Path ".\credentials" | Out-Null
@"
Kubernetes Dashboard Access Token
==================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Service Account: admin-user
Namespace: kubernetes-dashboard

Token:
$token

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

# Verify installation
Write-Host "`nDashboard pods:" -ForegroundColor Yellow
kubectl get pods -n kubernetes-dashboard
