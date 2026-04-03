#!/bin/bash
# Install cert-manager on the kind cluster

VERSION="${1:-v1.13.3}"

echo -e "\033[1;36mInstalling cert-manager $VERSION...\033[0m"

# Check if cert-manager is already installed
if kubectl get namespace cert-manager &> /dev/null; then
    echo -e "\033[1;32m✓ cert-manager is already installed\033[0m"
    
    # Check if pods are running
    if kubectl get pods -n cert-manager --field-selector=status.phase=Running &> /dev/null; then
        echo -e "  cert-manager pods are running"
        kubectl get pods -n cert-manager
    else
        echo -e "  \033[1;33mWARNING: cert-manager namespace exists but pods are not running\033[0m"
        kubectl get pods -n cert-manager
    fi
    
    exit 0
fi

# Install cert-manager
echo -e "\033[1;33mInstalling cert-manager components...\033[0m"
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/$VERSION/cert-manager.yaml"

# Wait for cert-manager to be ready
echo -e "\033[1;33mWaiting for cert-manager pods to be ready...\033[0m"
kubectl wait --for=condition=Ready pods --all -n cert-manager --timeout=300s

echo -e "\n\033[1;32mcert-manager installed successfully!\033[0m"

kubectl get pods -n cert-manager
