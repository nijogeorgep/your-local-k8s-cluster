#!/usr/bin/env pwsh
#
# Spring Kotlin App Deployment Script
# Deploys nijogeorgep/spring-kotlin-app:2c5c983 with Argo Rollouts, Istio, and Kargo
#
# Usage:
#   .\deploy-spring-kotlin-app.ps1                    # Interactive deployment
#   .\deploy-spring-kotlin-app.ps1 -NonInteractive    # CI/CD friendly
#   .\deploy-spring-kotlin-app.ps1 -SkipChecks        # Skip prerequisite checks
#   .\deploy-spring-kotlin-app.ps1 -Uninstall         # Remove deployment
#

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Skip user prompts for CI/CD pipelines")]
    [switch]$NonInteractive,
    
    [Parameter(HelpMessage = "Skip prerequisite checks")]
    [switch]$SkipChecks,
    
    [Parameter(HelpMessage = "Uninstall the application")]
    [switch]$Uninstall,
    
    [Parameter(HelpMessage = "Namespace to deploy into")]
    [string]$Namespace = "spring-kotlin-app",
    
    [Parameter(HelpMessage = "Helm release name")]
    [string]$ReleaseName = "spring-kotlin-app",
    
    [Parameter(HelpMessage = "Enable Kargo multi-environment setup")]
    [switch]$EnableKargo,
    
    [Parameter(HelpMessage = "Wait for rollout to complete")]
    [switch]$Wait
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Script directory and paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ValuesFile = Join-Path $ScriptDir "values-spring-kotlin-app.yaml"
$ChartDir = Join-Path (Split-Path -Parent (Split-Path -Parent $ScriptDir)) "helm-charts\app-template"

# Colors for output
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error-Custom { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Step { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Magenta }

# Banner
function Show-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          Spring Kotlin App - Deployment Script                      ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Image:     nijogeorgep/spring-kotlin-app:2c5c983" -ForegroundColor White
    Write-Host "  Namespace: $Namespace" -ForegroundColor White
    Write-Host "  Release:   $ReleaseName" -ForegroundColor White
    Write-Host ""
}

# Check if command exists
function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Run kubectl command and capture output
function Invoke-Kubectl {
    param([string]$Arguments)
    $output = kubectl $Arguments.Split() 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "kubectl command failed: $output"
    }
    return $output
}

# Check prerequisites
function Test-Prerequisites {
    Write-Step "Checking Prerequisites"
    
    $allGood = $true
    
    # Check kubectl
    if (Test-Command "kubectl") {
        Write-Success "kubectl is installed"
        try {
            $clusterInfo = kubectl cluster-info 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Kubernetes cluster is accessible"
            } else {
                Write-Error-Custom "Cannot connect to Kubernetes cluster"
                Write-Info "Run: kubectl cluster-info"
                $allGood = $false
            }
        } catch {
            Write-Error-Custom "Cannot connect to Kubernetes cluster"
            $allGood = $false
        }
    } else {
        Write-Error-Custom "kubectl is not installed"
        Write-Info "Install from: https://kubernetes.io/docs/tasks/tools/"
        $allGood = $false
    }
    
    # Check Helm
    if (Test-Command "helm") {
        Write-Success "Helm is installed"
    } else {
        Write-Error-Custom "Helm is not installed"
        Write-Info "Install from: https://helm.sh/docs/intro/install/"
        $allGood = $false
    }
    
    # Check Istio
    $istioDeployment = kubectl get deployment -n istio-system 2>&1 | Select-String "istiod"
    if ($istioDeployment) {
        Write-Success "Istio is installed"
    } else {
        Write-Warning "Istio might not be installed"
        Write-Info "Install with: .\scripts\install-istio.ps1"
        if (-not $NonInteractive) {
            $continue = Read-Host "Continue anyway? (y/N)"
            if ($continue -ne "y" -and $continue -ne "Y") {
                exit 1
            }
        }
    }
    
    # Check Argo Rollouts
    $argoRolloutsDeployment = kubectl get deployment argo-rollouts -n argo-rollouts 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Argo Rollouts is installed"
    } else {
        Write-Warning "Argo Rollouts might not be installed"
        Write-Info "Install with: .\scripts\install-argo-rollouts.ps1"
        if (-not $NonInteractive) {
            $continue = Read-Host "Continue anyway? (y/N)"
            if ($continue -ne "y" -and $continue -ne "Y") {
                exit 1
            }
        }
    }
    
    # Check Argo Rollouts kubectl plugin
    if (Test-Path "tools\kubectl-plugins\kubectl-argo-rollouts.exe") {
        Write-Success "Argo Rollouts kubectl plugin found"
    } elseif (Test-Command "kubectl-argo-rollouts") {
        Write-Success "Argo Rollouts kubectl plugin is installed"
    } else {
        Write-Warning "Argo Rollouts kubectl plugin not found"
        Write-Info "Install with: .\scripts\install-argo-rollouts.ps1"
    }
    
    # Check Kargo if enabled
    if ($EnableKargo) {
        $kargoDeployment = kubectl get deployment kargo-api -n kargo 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Kargo is installed"
        } else {
            Write-Warning "Kargo is not installed but EnableKargo flag is set"
            Write-Info "Install with: .\scripts\install-kargo.ps1"
            if (-not $NonInteractive) {
                $continue = Read-Host "Continue anyway? (y/N)"
                if ($continue -ne "y" -and $continue -ne "Y") {
                    exit 1
                }
            }
        }
    }
    
    # Check values file exists
    if (Test-Path $ValuesFile) {
        Write-Success "Values file found: $ValuesFile"
    } else {
        Write-Error-Custom "Values file not found: $ValuesFile"
        $allGood = $false
    }
    
    if (-not $allGood) {
        throw "Prerequisites check failed. Please install missing components."
    }
    
    Write-Host ""
}

# Uninstall application
function Remove-Application {
    Write-Step "Uninstalling Application"
    
    # Check if release exists
    $release = helm list -n $Namespace 2>&1 | Select-String $ReleaseName
    if (-not $release) {
        Write-Warning "Release '$ReleaseName' not found in namespace '$Namespace'"
        return
    }
    
    Write-Info "Uninstalling Helm release: $ReleaseName"
    helm uninstall $ReleaseName -n $Namespace
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Helm release uninstalled"
    } else {
        Write-Error-Custom "Failed to uninstall Helm release"
        exit 1
    }
    
    # Ask about namespace deletion
    if (-not $NonInteractive) {
        $deleteNs = Read-Host "Delete namespace '$Namespace'? (y/N)"
        if ($deleteNs -eq "y" -or $deleteNs -eq "Y") {
            Write-Info "Deleting namespace: $Namespace"
            kubectl delete namespace $Namespace --timeout=60s
            Write-Success "Namespace deleted"
        }
    }
    
    # Ask about Kargo namespaces
    if ($EnableKargo -and -not $NonInteractive) {
        $deleteKargo = Read-Host "Delete Kargo environment namespaces? (y/N)"
        if ($deleteKargo -eq "y" -or $deleteKargo -eq "Y") {
            Write-Info "Deleting Kargo namespaces..."
            kubectl delete namespace spring-kotlin-app-dev --ignore-not-found=true --timeout=60s
            kubectl delete namespace spring-kotlin-app-staging --ignore-not-found=true --timeout=60s
            kubectl delete namespace spring-kotlin-app-prod --ignore-not-found=true --timeout=60s
            kubectl delete namespace kargo-project-spring-kotlin-app --ignore-not-found=true --timeout=60s
            Write-Success "Kargo namespaces deleted"
        }
    }
    
    Write-Success "Uninstallation complete"
}

# Create namespace
function New-DeploymentNamespace {
    Write-Step "Creating Namespace"
    
    # Check if namespace exists
    $nsExists = kubectl get namespace $Namespace 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Warning "Namespace '$Namespace' already exists"
        
        # Check if it has Istio injection label
        $label = kubectl get namespace $Namespace -o jsonpath='{.metadata.labels.istio-injection}' 2>&1
        if ($label -eq "enabled") {
            Write-Success "Istio injection is already enabled"
        } else {
            Write-Info "Enabling Istio sidecar injection..."
            kubectl label namespace $Namespace istio-injection=enabled --overwrite
            Write-Success "Istio injection enabled"
        }
    } else {
        Write-Info "Creating namespace: $Namespace"
        kubectl create namespace $Namespace
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Namespace created"
            
            Write-Info "Enabling Istio sidecar injection..."
            kubectl label namespace $Namespace istio-injection=enabled
            Write-Success "Istio injection enabled"
        } else {
            throw "Failed to create namespace"
        }
    }
    
    Write-Host ""
}

# Create Kargo environment namespaces
function New-KargoNamespaces {
    Write-Step "Creating Kargo Environment Namespaces"
    
    $kargoNamespaces = @(
        "spring-kotlin-app-dev",
        "spring-kotlin-app-staging",
        "spring-kotlin-app-prod",
        "kargo-project-spring-kotlin-app"
    )
    
    foreach ($ns in $kargoNamespaces) {
        $nsExists = kubectl get namespace $ns 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Warning "Namespace '$ns' already exists"
        } else {
            Write-Info "Creating namespace: $ns"
            kubectl create namespace $ns
            
            # Enable Istio injection for app namespaces
            if ($ns -notlike "*project*") {
                kubectl label namespace $ns istio-injection=enabled
                Write-Success "Created $ns with Istio injection"
            } else {
                Write-Success "Created $ns"
            }
        }
    }
    
    Write-Host ""
}

# Deploy application with Helm
function Install-Application {
    Write-Step "Deploying Application with Helm"
    
    # Change to chart directory for Helm
    Push-Location $ChartDir
    
    try {
        # Check if already installed
        $release = helm list -n $Namespace 2>&1 | Select-String $ReleaseName
        if ($release) {
            Write-Warning "Release '$ReleaseName' already exists"
            if (-not $NonInteractive) {
                $upgrade = Read-Host "Upgrade existing release? (Y/n)"
                if ($upgrade -eq "n" -or $upgrade -eq "N") {
                    Write-Info "Skipping deployment"
                    return
                }
            }
            
            Write-Info "Upgrading Helm release: $ReleaseName"
            $helmArgs = @(
                "upgrade",
                $ReleaseName,
                ".",
                "-f", $ValuesFile,
                "-n", $Namespace
            )
            
            if ($EnableKargo) {
                $helmArgs += "--set", "kargo-config.enabled=true"
            }
            
            helm @helmArgs
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Application upgraded successfully"
            } else {
                throw "Helm upgrade failed"
            }
        } else {
            Write-Info "Installing Helm release: $ReleaseName"
            $helmArgs = @(
                "install",
                $ReleaseName,
                ".",
                "-f", $ValuesFile,
                "-n", $Namespace
            )
            
            if ($EnableKargo) {
                $helmArgs += "--set", "kargo-config.enabled=true"
            }
            
            helm @helmArgs
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Application deployed successfully"
            } else {
                throw "Helm installation failed"
            }
        }
    } finally {
        Pop-Location
    }
    
    Write-Host ""
}

# Verify deployment
function Test-Deployment {
    Write-Step "Verifying Deployment"
    
    Write-Info "Waiting for Rollout to be created..."
    Start-Sleep -Seconds 3
    
    # Check Rollout
    $rollout = kubectl get rollout $ReleaseName -n $Namespace 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Rollout created: $ReleaseName"
    } else {
        Write-Warning "Rollout not found (this is expected for first deployment)"
    }
    
    # Check Service
    $service = kubectl get service $ReleaseName -n $Namespace 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Service created: $ReleaseName"
    } else {
        Write-Warning "Service not found"
    }
    
    # Check VirtualService
    $vs = kubectl get virtualservice $ReleaseName -n $Namespace 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "VirtualService created: $ReleaseName"
    } else {
        Write-Warning "VirtualService not found"
    }
    
    # Check DestinationRule
    $dr = kubectl get destinationrule $ReleaseName -n $Namespace 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "DestinationRule created: $ReleaseName"
    } else {
        Write-Warning "DestinationRule not found"
    }
    
    # Check PeerAuthentication
    $pa = kubectl get peerauthentication $ReleaseName -n $Namespace 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "PeerAuthentication created (mTLS enabled)"
    } else {
        Write-Warning "PeerAuthentication not found"
    }
    
    # Wait for pods
    Write-Info "Waiting for pods to be ready (timeout: 120s)..."
    kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=$ReleaseName -n $Namespace --timeout=120s 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Pods are ready"
        
        # Show pod status
        Write-Host ""
        Write-Info "Pod Status:"
        kubectl get pods -l app.kubernetes.io/name=$ReleaseName -n $Namespace
    } else {
        Write-Warning "Pods are not ready yet"
        Write-Info "Check status with: kubectl get pods -n $Namespace"
    }
    
    # Check Kargo stages if enabled
    if ($EnableKargo) {
        Write-Host ""
        Write-Info "Checking Kargo stages..."
        $stages = kubectl get stages -n kargo-project-spring-kotlin-app 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Kargo stages created"
            kubectl get stages -n kargo-project-spring-kotlin-app
        } else {
            Write-Warning "Kargo stages not found"
        }
    }
    
    Write-Host ""
}

# Watch rollout progress
function Watch-RolloutProgress {
    Write-Step "Watching Rollout Progress"
    
    Write-Info "Monitoring canary deployment..."
    Write-Info "Press Ctrl+C to stop watching (deployment will continue)"
    Write-Host ""
    
    # Try to use kubectl plugin if available
    if (Test-Path "tools\kubectl-plugins\kubectl-argo-rollouts.exe") {
        & "tools\kubectl-plugins\kubectl-argo-rollouts.exe" get rollout $ReleaseName -n $Namespace --watch
    } elseif (Test-Command "kubectl-argo-rollouts") {
        kubectl argo rollouts get rollout $ReleaseName -n $Namespace --watch
    } else {
        Write-Warning "Argo Rollouts kubectl plugin not found"
        Write-Info "Falling back to pod watch..."
        kubectl get pods -l app.kubernetes.io/name=$ReleaseName -n $Namespace --watch
    }
}

# Show access instructions
function Show-AccessInstructions {
    Write-Step "Access Instructions"
    
    Write-Host ""
    Write-Info "Application has been deployed successfully!"
    Write-Host ""
    
    Write-Host "📊 Monitor Rollout Progress:" -ForegroundColor Yellow
    if (Test-Path "tools\kubectl-plugins\kubectl-argo-rollouts.exe") {
        Write-Host "   .\tools\kubectl-plugins\kubectl-argo-rollouts.exe get rollout $ReleaseName -n $Namespace --watch" -ForegroundColor Cyan
    } else {
        Write-Host "   kubectl argo rollouts get rollout $ReleaseName -n $Namespace --watch" -ForegroundColor Cyan
    }
    Write-Host ""
    
    Write-Host "🌐 Access Application:" -ForegroundColor Yellow
    Write-Host "   kubectl port-forward svc/$ReleaseName 8080:80 -n $Namespace" -ForegroundColor Cyan
    Write-Host "   Then open: http://localhost:8080/actuator/health" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "📈 Launch Argo Rollouts Dashboard:" -ForegroundColor Yellow
    if (Test-Path "tools\kubectl-plugins\kubectl-argo-rollouts.exe") {
        Write-Host "   .\tools\kubectl-plugins\kubectl-argo-rollouts.exe dashboard" -ForegroundColor Cyan
    } else {
        Write-Host "   kubectl argo rollouts dashboard" -ForegroundColor Cyan
    }
    Write-Host "   Then open: http://localhost:3100" -ForegroundColor Green
    Write-Host ""
    
    if ($EnableKargo) {
        Write-Host "🚀 Kargo UI:" -ForegroundColor Yellow
        Write-Host "   kubectl port-forward svc/kargo-api 8081:80 -n kargo" -ForegroundColor Cyan
        Write-Host "   Then open: http://localhost:8081" -ForegroundColor Green
        Write-Host ""
    }
    
    Write-Host "🔍 Useful Commands:" -ForegroundColor Yellow
    Write-Host "   # View all resources" -ForegroundColor White
    Write-Host "   kubectl get all,vs,dr,pa -n $Namespace" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   # View logs" -ForegroundColor White
    Write-Host "   kubectl logs -f -l app.kubernetes.io/name=$ReleaseName -n $Namespace -c spring-kotlin-app" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   # Promote canary" -ForegroundColor White
    Write-Host "   kubectl argo rollouts promote $ReleaseName -n $Namespace" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   # Rollback" -ForegroundColor White
    Write-Host "   kubectl argo rollouts abort $ReleaseName -n $Namespace" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "📚 Documentation:" -ForegroundColor Yellow
    Write-Host "   Full guide: SPRING-KOTLIN-APP-DEPLOYMENT.md" -ForegroundColor Cyan
    Write-Host "   Commands:   DEPLOY-COMMANDS.md" -ForegroundColor Cyan
    Write-Host "   Checklist:  DEPLOYMENT-CHECKLIST.md" -ForegroundColor Cyan
    Write-Host ""
}

# Main execution
try {
    Show-Banner
    
    # Handle uninstall
    if ($Uninstall) {
        Remove-Application
        exit 0
    }
    
    # Check prerequisites
    if (-not $SkipChecks) {
        Test-Prerequisites
    }
    
    # Create namespace
    New-DeploymentNamespace
    
    # Create Kargo namespaces if enabled
    if ($EnableKargo) {
        New-KargoNamespaces
    }
    
    # Deploy application
    Install-Application
    
    # Verify deployment
    Test-Deployment
    
    # Show access instructions
    Show-AccessInstructions
    
    # Watch rollout if requested
    if ($Wait) {
        Watch-RolloutProgress
    }
    
    Write-Success "Deployment script completed successfully!"
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Error-Custom "Deployment failed: $_"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check prerequisites: kubectl cluster-info" -ForegroundColor White
    Write-Host "  2. View events: kubectl get events -n $Namespace --sort-by='.lastTimestamp'" -ForegroundColor White
    Write-Host "  3. Check logs: kubectl logs -l app.kubernetes.io/name=$ReleaseName -n $Namespace" -ForegroundColor White
    Write-Host "  4. See full guide: SPRING-KOTLIN-APP-DEPLOYMENT.md" -ForegroundColor White
    Write-Host ""
    exit 1
}
