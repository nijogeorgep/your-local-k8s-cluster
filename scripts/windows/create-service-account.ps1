#!/usr/bin/env pwsh
# Create a custom service account with specific permissions

param(
    [Parameter(Mandatory=$true)]
    [string]$ServiceAccountName,
    
    [string]$Namespace = "default",
    
    [ValidateSet("cluster-admin", "admin", "edit", "view", "custom")]
    [string]$Role = "view",
    
    [string]$CustomClusterRole = ""
)

Write-Host "Creating service account '$ServiceAccountName' in namespace '$Namespace'..." -ForegroundColor Cyan

# Create namespace if it doesn't exist
kubectl create namespace $Namespace --dry-run=client -o yaml | kubectl apply -f -

# Create service account
$saYaml = @"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $ServiceAccountName
  namespace: $Namespace
"@

Write-Host "Creating service account..." -ForegroundColor Yellow
$saYaml | kubectl apply -f -

# Create role binding based on selected role
$bindingName = "$ServiceAccountName-binding"

if ($Role -eq "custom" -and $CustomClusterRole) {
    $roleToUse = $CustomClusterRole
} else {
    $roleToUse = $Role
}

$roleBindingYaml = @"
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $bindingName
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: $roleToUse
subjects:
- kind: ServiceAccount
  name: $ServiceAccountName
  namespace: $Namespace
"@

Write-Host "Creating cluster role binding with role: $roleToUse..." -ForegroundColor Yellow
$roleBindingYaml | kubectl apply -f -

# Create token secret
$secretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: $ServiceAccountName-token
  namespace: $Namespace
  annotations:
    kubernetes.io/service-account.name: $ServiceAccountName
type: kubernetes.io/service-account-token
"@

Write-Host "Creating token secret..." -ForegroundColor Yellow
$secretYaml | kubectl apply -f -

# Wait for token to be generated
Start-Sleep -Seconds 3

# Get the token
$token = kubectl get secret "$ServiceAccountName-token" -n $Namespace -o jsonpath="{.data.token}" 2>$null
if ($token) {
    $tokenDecoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($token))
} else {
    # For Kubernetes 1.24+
    $tokenDecoded = kubectl create token $ServiceAccountName -n $Namespace --duration=87600h
}

Write-Host "`nService Account created successfully!" -ForegroundColor Green
Write-Host "`nService Account: $ServiceAccountName" -ForegroundColor Cyan
Write-Host "Namespace: $Namespace" -ForegroundColor Cyan
Write-Host "Role: $roleToUse" -ForegroundColor Cyan

Write-Host "`nAccess Token:" -ForegroundColor Yellow
Write-Host $tokenDecoded -ForegroundColor White

# Save to file
$credsDir = ".\credentials\service-accounts"
New-Item -ItemType Directory -Force -Path $credsDir | Out-Null
$credsFile = "$credsDir\$ServiceAccountName-$Namespace.txt"

@"
Service Account Credentials
============================
Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Service Account: $ServiceAccountName
Namespace: $Namespace
Role: $roleToUse

Token:
$tokenDecoded

Usage Examples:
---------------
# Use with kubectl:
kubectl --token="$tokenDecoded" get pods

# Use in kubeconfig:
kubectl config set-credentials $ServiceAccountName --token="$tokenDecoded"
kubectl config set-context $ServiceAccountName-context --cluster=<cluster-name> --user=$ServiceAccountName
kubectl config use-context $ServiceAccountName-context

# Delete this service account:
kubectl delete serviceaccount $ServiceAccountName -n $Namespace
kubectl delete clusterrolebinding $bindingName
kubectl delete secret $ServiceAccountName-token -n $Namespace
"@ | Out-File -FilePath $credsFile -Encoding UTF8

Write-Host "`nCredentials saved to: $credsFile" -ForegroundColor Green

Write-Host "`nRole Permissions:" -ForegroundColor Yellow
switch ($Role) {
    "cluster-admin" { Write-Host "  Full cluster access (use with caution!)" -ForegroundColor Red }
    "admin" { Write-Host "  Full access to namespace resources" -ForegroundColor Yellow }
    "edit" { Write-Host "  Read/write access to most resources" -ForegroundColor Cyan }
    "view" { Write-Host "  Read-only access to resources" -ForegroundColor Green }
    "custom" { Write-Host "  Custom role: $CustomClusterRole" -ForegroundColor Cyan }
}
