#!/usr/bin/env pwsh
# Delete specific namespaces from the cluster

param(
    [Parameter(Mandatory=$false)]
    [string[]]$Namespaces = @(
        "spring-kotlin-app",
        "spring-kotlin-app-project",
        "kubernetes-dashboard",
        "kargo",
        "argo-rollouts",
        "argocd",
        "istio-system",
        "cert-manager"
    ),
    
    [switch]$Force,
    [int]$Timeout = 60
)

$ErrorActionPreference = "Continue"

Write-Host @"
╔═══════════════════════════════════════════════╗
║       Namespace Cleanup                       ║
║  Delete specified namespaces from cluster     ║
╚═══════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Check if cluster is accessible
Write-Host "`nChecking cluster connectivity..." -ForegroundColor Yellow
try {
    kubectl cluster-info 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Cluster not accessible"
    }
    Write-Host "✓ Cluster is accessible" -ForegroundColor Green
} catch {
    Write-Host "✗ Cannot connect to cluster" -ForegroundColor Red
    Write-Host "  Make sure your Kubernetes cluster is running" -ForegroundColor Yellow
    exit 1
}

# Show current namespaces
Write-Host "`nCurrent namespaces:" -ForegroundColor Cyan
kubectl get namespaces

# Confirm deletion
if (-not $Force) {
    Write-Host "`n⚠️  The following namespaces will be deleted:" -ForegroundColor Yellow
    foreach ($ns in $Namespaces) {
        $exists = kubectl get namespace $ns --ignore-not-found=true 2>$null
        if ($exists) {
            Write-Host "  • $ns" -ForegroundColor White
        } else {
            Write-Host "  • $ns (not found)" -ForegroundColor Gray
        }
    }
    
    $confirm = Read-Host "`nContinue? (y/n)"
    if ($confirm -ne 'y') {
        Write-Host "`n✓ Cleanup cancelled." -ForegroundColor Cyan
        exit 0
    }
}

# Delete namespaces
Write-Host "`n════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Deleting Namespaces" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════" -ForegroundColor Cyan

$deleted = @()
$notFound = @()
$failed = @()

foreach ($ns in $Namespaces) {
    $exists = kubectl get namespace $ns --ignore-not-found=true 2>$null
    
    if ($exists) {
        Write-Host "`nDeleting namespace: $ns" -ForegroundColor Yellow
        kubectl delete namespace $ns --timeout=${Timeout}s 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✓ Deleted successfully" -ForegroundColor Green
            $deleted += $ns
        } else {
            Write-Host "  ⚠️  Deletion initiated (may be terminating)" -ForegroundColor Yellow
            $failed += $ns
        }
    } else {
        Write-Host "  - Namespace '$ns' not found" -ForegroundColor Gray
        $notFound += $ns
    }
}

# Wait for terminating namespaces
if ($failed.Count -gt 0) {
    Write-Host "`nWaiting for terminating namespaces to complete..." -ForegroundColor Cyan
    Start-Sleep -Seconds 5
}

# Show final status
Write-Host "`n════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "Cleanup Complete" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════" -ForegroundColor Green

Write-Host "`n📊 Summary:" -ForegroundColor Cyan

if ($deleted.Count -gt 0) {
    Write-Host "`n✓ Successfully deleted ($($deleted.Count)):" -ForegroundColor Green
    foreach ($ns in $deleted) {
        Write-Host "  • $ns" -ForegroundColor White
    }
}

if ($failed.Count -gt 0) {
    Write-Host "`n⏳ Terminating ($($failed.Count)):" -ForegroundColor Yellow
    foreach ($ns in $failed) {
        Write-Host "  • $ns" -ForegroundColor White
    }
    Write-Host "`n💡 Note: These namespaces are being deleted in the background." -ForegroundColor Cyan
    Write-Host "   Resources with finalizers may take a few minutes to clean up." -ForegroundColor Cyan
}

if ($notFound.Count -gt 0) {
    Write-Host "`n- Not found ($($notFound.Count)):" -ForegroundColor Gray
    foreach ($ns in $notFound) {
        Write-Host "  • $ns" -ForegroundColor Gray
    }
}

Write-Host "`nFinal namespaces:" -ForegroundColor Cyan
kubectl get namespaces

Write-Host "`n✅ Cleanup script completed!`n" -ForegroundColor Green
