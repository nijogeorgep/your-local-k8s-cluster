#!/bin/bash
# Master installation script for all tools

set -e

# Parse command line arguments
SKIP_CERT_MANAGER=false
SKIP_ISTIO=false
SKIP_ARGOCD=false
SKIP_ARGO_ROLLOUTS=false
SKIP_KARGO=false
SKIP_DASHBOARD=false
NON_INTERACTIVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-cert-manager) SKIP_CERT_MANAGER=true; shift ;;
        --skip-istio) SKIP_ISTIO=true; shift ;;
        --skip-argocd) SKIP_ARGOCD=true; shift ;;
        --skip-argo-rollouts) SKIP_ARGO_ROLLOUTS=true; shift ;;
        --skip-kargo) SKIP_KARGO=true; shift ;;
        --skip-dashboard) SKIP_DASHBOARD=true; shift ;;
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

INTERACTIVE=$([[ "$NON_INTERACTIVE" == "false" ]] && echo "true" || echo "false")

cat << "EOF"
╔═══════════════════════════════════════════════╗
║   Local Kubernetes Cluster Setup             ║
║   Installing: cert-manager, Istio, ArgoCD,   ║
║              Argo Rollouts, Kargo, Dashboard  ║
╚═══════════════════════════════════════════════╝
EOF

# Verify prerequisites
echo -e "\n\033[1;33mVerifying prerequisites...\033[0m"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "\033[1;31mERROR: kubectl not found in PATH\033[0m"
    exit 1
fi

# Check helm (required for Kargo)
if ! command -v helm &> /dev/null; then
    echo -e "\033[1;33mWARNING: helm not found in PATH. Kargo installation will fail.\033[0m"
    if [[ "$INTERACTIVE" == "true" ]]; then
        read -p "Continue anyway? (y/n) " continue
        if [[ "$continue" != "y" ]]; then
            exit 1
        fi
    fi
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo -e "\033[1;31mERROR: Cannot connect to Kubernetes cluster\033[0m"
    exit 1
fi

echo -e "\033[1;32m✓ Cluster is accessible\033[0m"

# Installation sequence
echo -e "\n\033[1;36mStarting installation...\033[0m\n"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Install cert-manager
if [[ "$SKIP_CERT_MANAGER" == "false" ]]; then
    echo -e "\033[1;36m[1/6] Installing cert-manager...\033[0m"
    bash "$SCRIPT_DIR/install-cert-manager.sh"
else
    echo -e "\033[1;33m[1/6] Skipping cert-manager\033[0m"
fi

# Install Istio
if [[ "$SKIP_ISTIO" == "false" ]]; then
    echo -e "\n\033[1;36m[2/6] Installing Istio...\033[0m"
    bash "$SCRIPT_DIR/install-istio.sh"
else
    echo -e "\033[1;33m[2/6] Skipping Istio\033[0m"
fi

# Install ArgoCD
if [[ "$SKIP_ARGOCD" == "false" ]]; then
    echo -e "\n\033[1;36m[3/6] Installing ArgoCD...\033[0m"
    bash "$SCRIPT_DIR/install-argocd.sh"
else
    echo -e "\033[1;33m[3/6] Skipping ArgoCD\033[0m"
fi

# Install Argo Rollouts
if [[ "$SKIP_ARGO_ROLLOUTS" == "false" ]]; then
    echo -e "\n\033[1;36m[4/6] Installing Argo Rollouts...\033[0m"
    bash "$SCRIPT_DIR/install-argo-rollouts.sh"
else
    echo -e "\033[1;33m[4/6] Skipping Argo Rollouts\033[0m"
fi

# Install Kargo
if [[ "$SKIP_KARGO" == "false" ]]; then
    echo -e "\n\033[1;36m[5/6] Installing Kargo...\033[0m"
    bash "$SCRIPT_DIR/install-kargo.sh"
else
    echo -e "\033[1;33m[5/6] Skipping Kargo\033[0m"
fi

# Install Dashboard
if [[ "$SKIP_DASHBOARD" == "false" ]]; then
    echo -e "\n\033[1;36m[6/6] Installing Kubernetes Dashboard...\033[0m"
    bash "$SCRIPT_DIR/install-dashboard.sh"
else
    echo -e "\033[1;33m[6/6] Skipping Kubernetes Dashboard\033[0m"
fi

# Setup infrastructure
echo -e "\n\033[1;36mSetting up infrastructure...\033[0m"
bash "$SCRIPT_DIR/setup-infrastructure.sh"

# Final verification
echo -e "\n\033[1;36mVerifying installation...\033[0m"
bash "$SCRIPT_DIR/verify-cluster.sh"

echo -e "\n\033[1;32m╔════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;32m║  Installation Complete!                    ║\033[0m"
echo -e "\033[1;32m╚════════════════════════════════════════════╝\033[0m"

echo -e "\n\033[1;33mAccess UIs:\033[0m"
echo -e "  \033[1;36mKubernetes Dashboard:\033[0m"
echo -e "    kubectl proxy"
echo -e "    http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo -e "    Token: ./credentials/service-accounts/admin-user-kubernetes-dashboard.txt"

echo -e "\n  \033[1;36mArgoCD:\033[0m"
echo -e "    kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo -e "    https://localhost:8080"
echo -e "    Credentials: ./credentials/argocd-credentials.txt"

echo -e "\n  \033[1;36mKargo:\033[0m"
echo -e "    kubectl port-forward svc/kargo-api -n kargo 8081:443"
echo -e "    http://localhost:8081"

echo -e "\n  \033[1;36mArgo Rollouts Dashboard:\033[0m"
echo -e "    ./tools/kubectl-plugins/kubectl-argo-rollouts dashboard"
echo ""
