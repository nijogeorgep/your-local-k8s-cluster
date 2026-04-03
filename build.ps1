#!/usr/bin/env pwsh
# Build script for My Local Kubernetes Cluster
# PowerShell alternative to Makefile

param(
    [Parameter(Position=0)]
    [ValidateSet('help', 'install', 'install-quiet', 'verify', 'status', 'uninstall', 'clean', 
                 'create-cluster', 'delete-cluster', 'setup', 'teardown',
                 'install-istio', 'install-argocd', 'install-rollouts', 'install-kargo', 'install-dashboard',
                 'install-cert-manager', 'setup-infrastructure',
                 'dashboard', 'argocd-ui', 'kargo-ui', 'rollouts-ui', 'expose-gateway',
                 'helm-lint', 'helm-template', 'helm-test', 'helm-package', 'helm-verify', 'helm-build')]
    [string]$Target = 'help'
)

$ErrorActionPreference = "Stop"

function Show-Help {
    Write-Host @"
My Local Kubernetes Cluster - Available targets:

  .\build.ps1 install          - Install all components interactively
  .\build.ps1 install-quiet    - Install all components non-interactively
  .\build.ps1 verify           - Verify cluster status and installed components
  .\build.ps1 uninstall        - Remove all installed components (keeps cluster)
  .\build.ps1 clean            - Remove tools and credentials directories
  .\build.ps1 create-cluster   - Create the kind cluster
  .\build.ps1 delete-cluster   - Delete the kind cluster
  .\build.ps1 status           - Show cluster and component status

Component-specific installs:
  .\build.ps1 install-cert-manager
  .\build.ps1 install-istio
  .\build.ps1 install-argocd
  .\build.ps1 install-rollouts
  .\build.ps1 install-kargo
  .\build.ps1 install-dashboard

Access UIs:
  .\build.ps1 dashboard        - Start kubectl proxy for dashboard access
  .\build.ps1 argocd-ui        - Port-forward ArgoCD UI to https://localhost:8080
  .\build.ps1 kargo-ui         - Port-forward Kargo UI to http://localhost:8081
  .\build.ps1 rollouts-ui      - Launch Argo Rollouts dashboard
  .\build.ps1 expose-gateway   - Expose Istio gateway for path-based routing

Infrastructure:
  .\build.ps1 setup-infrastructure - Setup SSL certificates and Istio routing

Helm Chart Verification:
  .\build.ps1 helm-lint        - Lint Helm charts for errors
  .\build.ps1 helm-template    - Test chart template rendering
  .\build.ps1 helm-test        - Run Helm tests (requires deployment)
  .\build.ps1 helm-package     - Package Helm charts
  .\build.ps1 helm-verify      - Run all Helm verifications (lint + template)
  .\build.ps1 helm-build       - Build charts (update deps + verify + package)

Workflows:
  .\build.ps1 setup            - Complete setup (create + install + verify)
  .\build.ps1 teardown         - Complete teardown (uninstall + delete + clean)

"@ -ForegroundColor Cyan
}

switch ($Target) {
    'help' {
        Show-Help
    }
    'install' {
        & "$PSScriptRoot\scripts\windows\install-all.ps1"
    }
    'install-quiet' {
        & "$PSScriptRoot\scripts\windows\install-all.ps1" -NonInteractive
    }
    'install-cert-manager' {
        & "$PSScriptRoot\scripts\windows\install-cert-manager.ps1"
    }
    'install-istio' {
        & "$PSScriptRoot\scripts\windows\install-istio.ps1"
    }
    'install-argocd' {
        & "$PSScriptRoot\scripts\windows\install-argocd.ps1"
    }
    'install-rollouts' {
        & "$PSScriptRoot\scripts\windows\install-argo-rollouts.ps1"
    }
    'install-kargo' {
        & "$PSScriptRoot\scripts\windows\install-kargo.ps1"
    }
    'setup-infrastructure' {
        & "$PSScriptRoot\scripts\windows\setup-infrastructure.ps1"
    }
    'install-dashboard' {
        & "$PSScriptRoot\scripts\windows\install-dashboard.ps1"
    }
    'verify' {
        & "$PSScriptRoot\scripts\windows\verify-cluster.ps1"
    }
    'status' {
        & "$PSScriptRoot\scripts\windows\verify-cluster.ps1"
    }
    'create-cluster' {
        Write-Host "Creating kind cluster: my-local-cluster" -ForegroundColor Cyan
        kind create cluster --name my-local-cluster
    }
    'delete-cluster' {
        Write-Host "Deleting kind cluster: my-local-cluster" -ForegroundColor Yellow
        kind delete cluster --name my-local-cluster
    }
    'uninstall' {
        & "$PSScriptRoot\scripts\windows\uninstall-all.ps1"
    }
    'clean' {
        Write-Host "Cleaning up tools and credentials directories..." -ForegroundColor Yellow
        if (Test-Path "$PSScriptRoot\tools") {
            Remove-Item "$PSScriptRoot\tools" -Recurse -Force
            Write-Host "  ✓ Removed tools/" -ForegroundColor Green
        }
        if (Test-Path "$PSScriptRoot\credentials") {
            Remove-Item "$PSScriptRoot\credentials" -Recurse -Force
            Write-Host "  ✓ Removed credentials/" -ForegroundColor Green
        }
        Write-Host "Cleanup complete!" -ForegroundColor Green
    }
    'dashboard' {
        Write-Host "Starting kubectl proxy for dashboard access..." -ForegroundColor Cyan
        Write-Host "Access dashboard at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/" -ForegroundColor White
        Write-Host "Token location: ./credentials/dashboard-token.txt" -ForegroundColor Yellow
        kubectl proxy
    }
    'argocd-ui' {
        Write-Host "Port-forwarding ArgoCD UI to https://localhost:8080" -ForegroundColor Cyan
        Write-Host "Credentials location: ./credentials/argocd-credentials.txt" -ForegroundColor Yellow
        kubectl port-forward svc/argocd-server -n argocd 8080:443
    }
    'kargo-ui' {
        Write-Host "Port-forwarding Kargo UI to http://localhost:8081" -ForegroundColor Cyan
        kubectl port-forward svc/kargo-api -n kargo 8081:80
    }
    'rollouts-ui' {
        Write-Host "Launching Argo Rollouts dashboard..." -ForegroundColor Cyan
        $rollouts = "$PSScriptRoot\tools\kubectl-plugins\kubectl-argo-rollouts.exe"
        if (Test-Path $rollouts) {
            & $rollouts dashboard
        } else {
            Write-Host "ERROR: kubectl-argo-rollouts plugin not found." -ForegroundColor Red
     expose-gateway' {
        Write-Host "Exposing Istio Ingress Gateway..." -ForegroundColor Cyan
        Write-Host "Access URLs:" -ForegroundColor Yellow
        Write-Host "  ArgoCD:             https://localhost:8443/argocd" -ForegroundColor White
        Write-Host "  Kargo:              https://localhost:8443/kargo" -ForegroundColor White
        Write-Host "  Dashboard:          https://localhost:8443/dashboard" -ForegroundColor White
        Write-Host "  Argo Rollouts:      https://localhost:8443/rollouts" -ForegroundColor White
        Write-Host "`nPress Ctrl+C to stop port-forwarding" -ForegroundColor Yellow
        kubectl port-forward -n istio-system svc/istio-ingressgateway 8443:443 8080:80
    }
    '       Write-Host "Run '.\build.ps1 install-rollouts' first." -ForegroundColor Yellow
        }
    }
    'setup' {
        Write-Host "`n=== Complete Setup Workflow ===" -ForegroundColor Cyan
        Write-Host "1. Creating cluster..." -ForegroundColor Yellow
        kind create cluster --name my-local-cluster
        
        Write-Host "`n2. Installing components..." -ForegroundColor Yellow
        & "$PSScriptRoot\scripts\windows\install-all.ps1" -NonInteractive

        Write-Host "`n3. Verifying installation..." -ForegroundColor Yellow
        & "$PSScriptRoot\scripts\windows\verify-cluster.ps1"
        
        Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
        Write-Host "Your local Kubernetes cluster is ready." -ForegroundColor Green
    }
    'teardown' {
        Write-Host "`n=== Complete Teardown Workflow ===" -ForegroundColor Yellow
        
        $confirm = Read-Host "This will remove the cluster and all data. Continue? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Host "Teardown cancelled." -ForegroundColor Cyan
            return
        }
        
        Write-Host "`n1. Uninstalling components..." -ForegroundColor Yellow
        & "$PSScriptRoot\scripts\windows\uninstall-all.ps1" -Force
        
        Write-Host "`n2. Deleting cluster..." -ForegroundColor Yellow
        kind delete cluster --name my-local-cluster
        
        Write-Host "`n3. Cleaning directories..." -ForegroundColor Yellow
        if (Test-Path "$PSScriptRoot\tools") {
            Remove-Item "$PSScriptRoot\tools" -Recurse -Force
        }
        if (Test-Path "$PSScriptRoot\credentials") {
            Remove-Item "$PSScriptRoot\credentials" -Recurse -Force
        }
        
        Write-Host "`n=== Teardown Complete! ===" -ForegroundColor Green
    }
    'helm-lint' {
        Write-Host "`n=== Linting Helm Charts ===" -ForegroundColor Cyan
        $chartPath = "$PSScriptRoot\helm-charts\app-template"
        
        if (-not (Test-Path $chartPath)) {
            Write-Host "ERROR: Chart not found at $chartPath" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "Linting chart: app-template" -ForegroundColor Yellow
        helm lint $chartPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✓ Helm lint passed!" -ForegroundColor Green
        } else {
            Write-Host "`n✗ Helm lint failed!" -ForegroundColor Red
            exit 1
        }
    }
    'helm-template' {
        Write-Host "`n=== Testing Chart Template Rendering ===" -ForegroundColor Cyan
        $chartPath = "$PSScriptRoot\helm-charts\app-template"
        
        Write-Host "Testing basic rendering..." -ForegroundColor Yellow
        helm template test-app $chartPath --debug 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "✗ Basic template rendering failed!" -ForegroundColor Red
            exit 1
        }
        Write-Host "✓ Basic rendering passed" -ForegroundColor Green
        
        Write-Host "`nTesting with Istio routing..." -ForegroundColor Yellow
        helm template test-app $chartPath --set istio-routing.ingress.path=/test --debug 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "✗ Istio routing template failed!" -ForegroundColor Red
            exit 1
        }
        Write-Host "✓ Istio routing passed" -ForegroundColor Green
        
        Write-Host "`nTesting with canary enabled..." -ForegroundColor Yellow
        helm template test-app $chartPath --set istio-routing.trafficRouting.enabled=true --debug 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "✗ Canary template failed!" -ForegroundColor Red
            exit 1
        }
        Write-Host "✓ Canary routing passed" -ForegroundColor Green
        
        Write-Host "`nTesting with Kargo enabled..." -ForegroundColor Yellow
        helm template test-app $chartPath --set kargo-config.enabled=true --debug 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "✗ Kargo template failed!" -ForegroundColor Red
            exit 1
        }
        Write-Host "✓ Kargo config passed" -ForegroundColor Green
        
        Write-Host "`n✓ All template tests passed!" -ForegroundColor Green
    }
    'helm-test' {
        Write-Host "`n=== Running Helm Tests ===" -ForegroundColor Cyan
        
        $releases = helm list -o json | ConvertFrom-Json
        if ($releases.Count -eq 0) {
            Write-Host "No Helm releases found. Deploy a chart first:" -ForegroundColor Yellow
            Write-Host "  helm install myapp ./helm-charts/app-template --wait" -ForegroundColor White
            exit 1
        }
        
        Write-Host "Available releases:" -ForegroundColor Yellow
        $releases | ForEach-Object { Write-Host "  - $($_.name) (namespace: $($_.namespace))" -ForegroundColor White }
        
        $releaseName = Read-Host "`nEnter release name to test"
        
        if ($releaseName) {
            Write-Host "`nRunning tests for release: $releaseName" -ForegroundColor Cyan
            helm test $releaseName --logs
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n✓ All tests passed!" -ForegroundColor Green
            } else {
                Write-Host "`n✗ Some tests failed. Check logs above." -ForegroundColor Red
                exit 1
            }
        } else {
            Write-Host "No release name provided." -ForegroundColor Yellow
        }
    }
    'helm-package' {
        Write-Host "`n=== Packaging Helm Charts ===" -ForegroundColor Cyan
        $chartPath = "$PSScriptRoot\helm-charts\app-template"
        $outputDir = "$PSScriptRoot\helm-charts\packages"
        
        # Create output directory
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }
        
        Write-Host "Updating dependencies..." -ForegroundColor Yellow
        Push-Location $chartPath
        helm dependency update
        Pop-Location
        
        Write-Host "`nPackaging chart..." -ForegroundColor Yellow
        helm package $chartPath --destination $outputDir
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✓ Chart packaged successfully!" -ForegroundColor Green
            Write-Host "Package location: $outputDir" -ForegroundColor Cyan
            Get-ChildItem $outputDir -Filter "*.tgz" | ForEach-Object {
                Write-Host "  - $($_.Name)" -ForegroundColor White
            }
        } else {
            Write-Host "`n✗ Packaging failed!" -ForegroundColor Red
            exit 1
        }
    }
    'helm-verify' {
        Write-Host "`n=== Running All Helm Verifications ===" -ForegroundColor Cyan
        
        # Run lint
        Write-Host "`n[1/2] Running helm lint..." -ForegroundColor Yellow
        & $PSCommandPath helm-lint
        if ($LASTEXITCODE -ne 0) { exit 1 }
        
        # Run template tests
        Write-Host "`n[2/2] Running template tests..." -ForegroundColor Yellow
        & $PSCommandPath helm-template
        if ($LASTEXITCODE -ne 0) { exit 1 }
        
        Write-Host "`n═══════════════════════════════════════" -ForegroundColor Green
        Write-Host "✓ All Helm verifications passed!" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════" -ForegroundColor Green
    }
    'helm-build' {
        Write-Host "`n=== Building Helm Charts ===" -ForegroundColor Cyan
        
        # Update dependencies
        Write-Host "`n[1/4] Updating dependencies..." -ForegroundColor Yellow
        $chartPath = "$PSScriptRoot\helm-charts\app-template"
        Push-Location $chartPath
        helm dependency update
        Pop-Location
        if ($LASTEXITCODE -ne 0) { 
            Write-Host "✗ Dependency update failed!" -ForegroundColor Red
            exit 1 
        }
        Write-Host "✓ Dependencies updated" -ForegroundColor Green
        
        # Run lint
        Write-Host "`n[2/4] Linting charts..." -ForegroundColor Yellow
        & $PSCommandPath helm-lint
        if ($LASTEXITCODE -ne 0) { exit 1 }
        
        # Run template tests
        Write-Host "`n[3/4] Testing templates..." -ForegroundColor Yellow
        & $PSCommandPath helm-template
        if ($LASTEXITCODE -ne 0) { exit 1 }
        
        # Package charts
        Write-Host "`n[4/4] Packaging charts..." -ForegroundColor Yellow
        & $PSCommandPath helm-package
        if ($LASTEXITCODE -ne 0) { exit 1 }
        
        Write-Host "`n═══════════════════════════════════════" -ForegroundColor Green
        Write-Host "✓ Helm chart build complete!" -ForegroundColor Green
        Write-Host "═══════════════════════════════════════" -ForegroundColor Green
    }
    default {
        Write-Host "Unknown target: $Target" -ForegroundColor Red
        Show-Help
        exit 1
    }
}
