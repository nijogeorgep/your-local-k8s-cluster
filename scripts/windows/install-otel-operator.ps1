#!/usr/bin/env pwsh
# Install OpenTelemetry Operator on the kind cluster
# Manages OpenTelemetryCollector and Instrumentation CRs; uses cert-manager for webhook TLS

param(
    [string]$Version = ""  # Empty string means latest version
)

Write-Host "Installing OpenTelemetry Operator..." -ForegroundColor Cyan

# cert-manager is required for admission webhook TLS
Write-Host "Checking cert-manager prerequisite..." -ForegroundColor Yellow
& "$PSScriptRoot\install-cert-manager.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: cert-manager installation failed" -ForegroundColor Red
    exit 1
}

# Idempotency check
$otelNamespace = kubectl get namespace opentelemetry-operator --ignore-not-found=true 2>$null
if ($otelNamespace) {
    $otelDeployments = kubectl get deployments -n opentelemetry-operator --ignore-not-found=true 2>$null
    if ($otelDeployments) {
        Write-Host "✓ OpenTelemetry Operator is already installed" -ForegroundColor Green

        $otelPods = kubectl get pods -n opentelemetry-operator --field-selector=status.phase=Running --ignore-not-found=true 2>$null
        if ($otelPods) {
            Write-Host "  Pods are running" -ForegroundColor Green
            kubectl get pods -n opentelemetry-operator
        } else {
            Write-Host "  WARNING: opentelemetry-operator namespace exists but pods may not be running" -ForegroundColor Yellow
            kubectl get pods -n opentelemetry-operator
        }

        exit 0
    }
}

# Create namespace
Write-Host "Creating opentelemetry-operator namespace..." -ForegroundColor Yellow
kubectl create namespace opentelemetry-operator --dry-run=client -o yaml | kubectl apply -f -

# Add / refresh Helm repo
Write-Host "Adding open-telemetry Helm repository..." -ForegroundColor Yellow
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 2>$null
helm repo update open-telemetry

# Build install arguments
$helmArgs = @(
    "install", "opentelemetry-operator", "open-telemetry/opentelemetry-operator",
    "--namespace", "opentelemetry-operator",
    "--set", "manager.collectorImage.repository=otel/opentelemetry-collector-k8s",
    "--set", "admissionWebhooks.certManager.enabled=true",
    "--wait", "--timeout", "5m"
)
if ($Version) {
    $helmArgs += @("--version", $Version)
}

Write-Host "Installing OpenTelemetry Operator via Helm..." -ForegroundColor Yellow
helm @helmArgs
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Helm install failed" -ForegroundColor Red
    exit 1
}

# Verify
Write-Host "`nVerifying OpenTelemetry Operator installation..." -ForegroundColor Yellow
kubectl get pods -n opentelemetry-operator

Write-Host "`nOpenTelemetry Operator installed successfully!" -ForegroundColor Green
Write-Host "`nThe operator manages OpenTelemetryCollector and Instrumentation resources." -ForegroundColor Cyan
Write-Host "Deploy an example collector:" -ForegroundColor Cyan
Write-Host "  kubectl apply -f manifests/examples/otel-collector.yaml" -ForegroundColor White
Write-Host "List collectors:" -ForegroundColor Cyan
Write-Host "  kubectl get opentelemetrycollectors -A" -ForegroundColor White
