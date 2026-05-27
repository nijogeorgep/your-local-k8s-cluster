# Makefile for My Local Kubernetes Cluster
# Requires: Make for Windows (choco install make) or WSL

.PHONY: help install install-quiet verify uninstall clean create-cluster delete-cluster status \
        helm-lint helm-template helm-test helm-package helm-verify helm-build \
        install-otel-operator

# Default target
help:
	@echo "My Local Kubernetes Cluster - Available targets:"
	@echo ""
	@echo "  make install          - Install all components interactively"
	@echo "  make install-quiet    - Install all components non-interactively"
	@echo "  make verify           - Verify cluster status and installed components"
	@echo "  make uninstall        - Remove all installed components (keeps cluster)"
	@echo "  make clean            - Remove tools and credentials directories"
	@echo "  make create-cluster   - Create the kind cluster"
	@echo "  make delete-cluster   - Delete the kind cluster"
	@echo "  make status           - Show cluster and component status"
	@echo ""
	@echo "Component-specific installs:"
	@echo "  make install-cert-manager"
	@echo "  make install-istio"
	@echo "  make install-argocd"
	@echo "  make install-rollouts"
	@echo "  make install-kargo"
	@echo "  make install-dashboard"
	@echo "  make install-otel-operator"
	@echo ""
	@echo "Access UIs:"
	@echo "  make dashboard        - Start kubectl proxy for dashboard access"
	@echo "  make argocd-ui        - Port-forward ArgoCD UI to https://localhost:8080"
	@echo "  make kargo-ui         - Port-forward Kargo UI to http://localhost:8081"
	@echo "  make rollouts-ui      - Launch Argo Rollouts dashboard"
	@echo ""
	@echo "Helm Chart Verification:"
	@echo "  make helm-lint        - Lint Helm charts for errors"
	@echo "  make helm-template    - Test chart template rendering"
	@echo "  make helm-test        - Run Helm tests (requires deployment)"
	@echo "  make helm-package     - Package Helm charts"
	@echo "  make helm-verify      - Run all verifications (lint + template)"
	@echo "  make helm-build       - Build charts (deps + verify + package)"

# Installation targets
install:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/install-all.ps1

install-quiet:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/install-all.ps1 -NonInteractive

install-cert-manager:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/install-cert-manager.ps1

install-istio:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/install-istio.ps1

install-argocd:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/install-argocd.ps1

install-rollouts:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/install-argo-rollouts.ps1

install-kargo:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/install-kargo.ps1

install-dashboard:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/install-dashboard.ps1

install-otel-operator:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/windows/install-otel-operator.ps1

# Verification and status
verify:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/verify-cluster.ps1

status: verify

# Cluster management
create-cluster:
	@echo "Creating kind cluster: my-local-cluster"
	@kind create cluster --name my-local-cluster

delete-cluster:
	@echo "Deleting kind cluster: my-local-cluster"
	@kind delete cluster --name my-local-cluster

# Cleanup
uninstall:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/uninstall-all.ps1

clean:
	@echo "Cleaning up tools and credentials directories..."
	@if exist tools rmdir /s /q tools
	@if exist credentials rmdir /s /q credentials
	@echo "Cleanup complete!"

# UI access helpers
dashboard:
	@echo "Starting kubectl proxy for dashboard access..."
	@echo "Access dashboard at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
	@echo "Token location: ./credentials/dashboard-token.txt"
	@kubectl proxy

argocd-ui:
	@echo "Port-forwarding ArgoCD UI to https://localhost:8080"
	@echo "Credentials location: ./credentials/argocd-credentials.txt"
	@kubectl port-forward svc/argocd-server -n argocd 8080:443

kargo-ui:
	@echo "Port-forwarding Kargo UI to http://localhost:8081"
	@kubectl port-forward svc/kargo-api -n kargo 8081:80

rollouts-ui:
	@echo "Launching Argo Rollouts dashboard..."
	@if exist ./tools/kubectl-plugins/kubectl-argo-rollouts.exe (./tools/kubectl-plugins/kubectl-argo-rollouts.exe dashboard) else (echo "ERROR: kubectl-argo-rollouts plugin not found. Run 'make install-rollouts' first.")

# Full setup workflow
setup: create-cluster install verify
	@echo ""
	@echo "Setup complete! Your local Kubernetes cluster is ready."

# Complete teardown
teardown: uninstall delete-cluster clean
	@echo ""
	@echo "Teardown complete! All components removed."

# Helm Chart Verification Targets
helm-lint:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./build.ps1 helm-lint

helm-template:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./build.ps1 helm-template

helm-test:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./build.ps1 helm-test

helm-package:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./build.ps1 helm-package

helm-verify:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./build.ps1 helm-verify

helm-build:
	@pwsh -NoProfile -ExecutionPolicy Bypass -File ./build.ps1 helm-build
