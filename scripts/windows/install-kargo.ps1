#!/usr/bin/env pwsh
# Install Kargo on the kind cluster

param(
    [string]$Version = ""  # Empty string means latest version
)

Write-Host "Installing Kargo..." -ForegroundColor Cyan

# Install cert-manager as prerequisite
Write-Host "Checking cert-manager prerequisite..." -ForegroundColor Yellow
& "$PSScriptRoot\install-cert-manager.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: cert-manager installation failed" -ForegroundColor Red
    exit 1
}

# Check if Kargo is already installed
$kargoNamespace = kubectl get namespace kargo --ignore-not-found=true 2>$null
if ($kargoNamespace) {
    # Check for deployments to see if it's actually installed
    $kargoDeployments = kubectl get deployments -n kargo --ignore-not-found=true 2>$null
    if ($kargoDeployments) {
        Write-Host "✓ Kargo is already installed" -ForegroundColor Green
        
        # Check if pods are running
        $kargoPods = kubectl get pods -n kargo --field-selector=status.phase=Running --ignore-not-found=true 2>$null
        if ($kargoPods) {
            Write-Host "  Pods are running" -ForegroundColor Green
            kubectl get pods -n kargo
        } else {
            Write-Host "  WARNING: Kargo namespace exists but pods may not be running" -ForegroundColor Yellow
            kubectl get pods -n kargo
        }
        
        Write-Host "`n  To access Kargo UI:" -ForegroundColor Yellow
        Write-Host "    kubectl port-forward svc/kargo-api -n kargo 8081:80" -ForegroundColor White
        exit 0
    }
}

# Create namespace if it doesn't exist
Write-Host "Creating kargo namespace..." -ForegroundColor Yellow
kubectl create namespace kargo --dry-run=client -o yaml | kubectl apply -f -

# Generate admin password using openssl (equivalent to: openssl rand -base64 48 | tr -d "=+/" | head -c 32)
Write-Host "Generating admin credentials..." -ForegroundColor Yellow
$adminPassword = ""
$passwordHash = ""
$tokenSigningKey = ""

# Generate password: random 32 characters from base64 without =+/
$randomBytes = New-Object byte[] 48
[System.Security.Cryptography.RandomNumberGenerator]::Fill($randomBytes)
$adminPassword = [Convert]::ToBase64String($randomBytes) -replace '[=+/]', '' | Select-Object -First 1 | ForEach-Object { $_.Substring(0, [Math]::Min(32, $_.Length)) }

# Generate password hash using htpasswd (requires Docker with httpd image)
# Equivalent to: htpasswd -bnBC 10 "" $pass | tr -d ':\n'
try {
    $htpasswdOutput = docker run --rm httpd:alpine htpasswd -bnBC 10 "" $adminPassword 2>$null
    $passwordHash = $htpasswdOutput -replace ':', '' -replace "`n", '' -replace "`r", ''
    Write-Host "  Generated password hash using htpasswd" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Docker is required to generate password hash" -ForegroundColor Red
    Write-Host "  Please ensure Docker is running and try again" -ForegroundColor Yellow
    exit 1
}

# Generate signing key: random 32 characters from base64 without =+/
$signingBytes = New-Object byte[] 48
[System.Security.Cryptography.RandomNumberGenerator]::Fill($signingBytes)
$tokenSigningKey = [Convert]::ToBase64String($signingBytes) -replace '[=+/]', '' | Select-Object -First 1 | ForEach-Object { $_.Substring(0, [Math]::Min(32, $_.Length)) }

Write-Host "  Password: $adminPassword" -ForegroundColor Cyan
Write-Host "  Signing Key: $tokenSigningKey" -ForegroundColor Cyan

# Create Kubernetes secret with admin credentials
Write-Host "Creating Kubernetes secret for admin credentials..." -ForegroundColor Yellow
$secretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: kargo-admin-secret
  namespace: kargo
type: Opaque
stringData:
  admin-password: "$adminPassword"
  admin-password-hash: "$passwordHash"
  token-signing-key: "$tokenSigningKey"
"@

$secretYaml | kubectl apply -f -

# Install Kargo using Helm with OCI registry, referencing the secret
Write-Host "Installing Kargo via Helm from OCI registry..." -ForegroundColor Yellow

$helmArgs = @(
    "install", "kargo",
    "oci://ghcr.io/akuity/kargo-charts/kargo",
    "--namespace", "kargo",
    "--create-namespace",
    "--set", "api.adminAccount.passwordHash=$passwordHash",
    "--set", "api.adminAccount.tokenSigningKey=$tokenSigningKey",
    "--wait"
)

# Add version if specified
if ($Version) {
    $helmArgs += "--version", $Version
    Write-Host "  Using version: $Version" -ForegroundColor Cyan
} else {
    Write-Host "  Using latest version" -ForegroundColor Cyan
}

helm @helmArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Kargo installation failed" -ForegroundColor Red
    exit 1
}

# Wait for Kargo to be ready
Write-Host "`nWaiting for Kargo pods to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5  # Give pods time to start creating
kubectl wait --for=condition=Ready pods --all -n kargo --timeout=300s 2>&1 | Out-Null

Write-Host "`nVerifying Kargo installation..." -ForegroundColor Yellow
kubectl get pods -n kargo

# Save credentials
$credsDir = ".\credentials"
New-Item -ItemType Directory -Force -Path $credsDir | Out-Null
$credsFile = "$credsDir\kargo-credentials.txt"

@"
Kargo Credentials
=================
URL: http://localhost:8081 (after port-forward)
Username: admin
Password: $adminPassword

Port-forward command:
kubectl port-forward svc/kargo-api -n kargo 8081:80

Documentation: https://docs.kargo.io/
"@ | Out-File -FilePath $credsFile -Encoding UTF8

Write-Host "`nKargo installed successfully!" -ForegroundColor Green
Write-Host "`nCredentials:" -ForegroundColor Cyan
Write-Host "  Username: admin" -ForegroundColor White
Write-Host "  Password: $adminPassword" -ForegroundColor White
Write-Host "  Saved to: $credsFile" -ForegroundColor Green

Write-Host "`nTo access Kargo UI, run:" -ForegroundColor Yellow
Write-Host "  kubectl port-forward svc/kargo-api -n kargo 8081:80" -ForegroundColor White
Write-Host "  Then navigate to: http://localhost:8081" -ForegroundColor White

Write-Host "`nFor more information:" -ForegroundColor Cyan
Write-Host "  Documentation: https://docs.kargo.io/" -ForegroundColor White
