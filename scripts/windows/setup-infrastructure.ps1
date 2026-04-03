#!/usr/bin/env pwsh
# Setup infrastructure for SSL certificates and Istio routing

param(
    [switch]$SkipCertIssuers,
    [switch]$SkipCertificate,
    [switch]$SkipGateway,
    [switch]$SkipToolsRouting
)

Write-Host "Setting up cluster infrastructure..." -ForegroundColor Cyan

# Apply cert-manager issuers
if (-not $SkipCertIssuers) {
    Write-Host "`nApplying cert-manager ClusterIssuers..." -ForegroundColor Yellow
    kubectl apply -f .\manifests\infrastructure\cert-issuers.yaml
}

# Create cluster certificate
if (-not $SkipCertificate) {
    Write-Host "`nCreating cluster TLS certificate..." -ForegroundColor Yellow
    kubectl apply -f .\manifests\infrastructure\cluster-certificate.yaml
    
    Write-Host "Waiting for certificate to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    kubectl wait --for=condition=Ready certificate/local-cluster-tls -n istio-system --timeout=300s
    
    Write-Host "✓ Certificate issued successfully" -ForegroundColor Green
}

# Apply Istio Gateway
if (-not $SkipGateway) {
    Write-Host "`nApplying Istio Gateway..." -ForegroundColor Yellow
    kubectl apply -f .\manifests\infrastructure\istio-gateway.yaml
}

# Apply tools routing
if (-not $SkipToolsRouting) {
    Write-Host "`nApplying tools routing (VirtualServices)..." -ForegroundColor Yellow
    kubectl apply -f .\manifests\infrastructure\tools-routing.yaml
}

Write-Host "`n✓ Infrastructure setup complete!" -ForegroundColor Green

Write-Host "`nInfrastructure Status:" -ForegroundColor Cyan
Write-Host "  Certificate Issuers:" -ForegroundColor Yellow
kubectl get clusterissuers

Write-Host "`n  Certificates:" -ForegroundColor Yellow
kubectl get certificates -n istio-system

Write-Host "`n  Istio Gateway:" -ForegroundColor Yellow
kubectl get gateway -n istio-system

Write-Host "`n  VirtualServices:" -ForegroundColor Yellow
kubectl get virtualservices -A

Write-Host "`nAccess URLs (after exposing the gateway):" -ForegroundColor Cyan
Write-Host "  ArgoCD:             https://localhost/argocd" -ForegroundColor White
Write-Host "  Kargo:              https://localhost/kargo" -ForegroundColor White
Write-Host "  Dashboard:          https://localhost/dashboard" -ForegroundColor White
Write-Host "  Argo Rollouts:      https://localhost/rollouts" -ForegroundColor White

Write-Host "`nTo expose the gateway, run:" -ForegroundColor Yellow
Write-Host "  kubectl port-forward -n istio-system svc/istio-ingressgateway 8443:443 8080:80" -ForegroundColor White
Write-Host "  Then access: https://localhost:8443/argocd" -ForegroundColor White
