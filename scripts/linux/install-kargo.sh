#!/bin/bash
# Install Kargo on the kind cluster

VERSION="${1:-1.1.2}"

echo -e "\033[1;36mInstalling Kargo v$VERSION...\033[0m"

# Check if Kargo is already installed
if kubectl get namespace kargo &> /dev/null; then
    echo -e "\033[1;32m✓ Kargo is already installed\033[0m"
    
    # Check if pods are running
    if kubectl get pods -n kargo --field-selector=status.phase=Running &> /dev/null; then
        echo -e "  Kargo pods are running"
        kubectl get pods -n kargo
    else
        echo -e "  \033[1;33mWARNING: Kargo namespace exists but pods are not all running\033[0m"
        kubectl get pods -n kargo
    fi
    
    # Get admin password if available
    if kubectl get secret kargo-admin-secret -n kargo &> /dev/null; then
        ADMIN_PASSWORD=$(kubectl -n kargo get secret kargo-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
        if [[ -n "$ADMIN_PASSWORD" ]]; then
            echo -e "\n  Username: admin"
            echo -e "  Password: $ADMIN_PASSWORD"
        fi
    fi
    
    echo -e "\n  \033[1;33mTo access Kargo UI:\033[0m"
    echo -e "    kubectl port-forward svc/kargo-api -n kargo 8081:443"
    echo -e "    Then navigate to: http://localhost:8081"
    exit 0
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "\033[1;31mERROR: helm is required but not installed\033[0m"
    echo -e "Install from: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Add Kargo Helm repository
echo -e "\033[1;33mAdding Kargo Helm repository...\033[0m"
helm repo add kargo https://charts.kargo.io
helm repo update

# Create namespace
echo -e "\033[1;33mCreating kargo namespace...\033[0m"
kubectl create namespace kargo --dry-run=client -o yaml | kubectl apply -f -

# Install Kargo using Helm
echo -e "\033[1;33mInstalling Kargo via Helm...\033[0m"
helm install kargo kargo/kargo \
    --namespace kargo \
    --version "$VERSION" \
    --wait \
    --timeout 10m

# Wait for all pods to be ready
echo -e "\033[1;33mWaiting for Kargo pods to be ready...\033[0m"
kubectl wait --for=condition=Ready pods --all -n kargo --timeout=300s

# Try to get admin password
ADMIN_PASSWORD=$(kubectl -n kargo get secret kargo-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

echo -e "\n\033[1;32mKargo installed successfully!\033[0m"

if [[ -n "$ADMIN_PASSWORD" ]]; then
    echo -e "\033[1;36mUsername:\033[0m admin"
    echo -e "\033[1;36mPassword:\033[0m $ADMIN_PASSWORD"
    
    # Save credentials
    CREDS_FILE="./credentials/kargo-credentials.txt"
    mkdir -p ./credentials
    
    cat > "$CREDS_FILE" << EOF
Kargo Credentials
=================
URL: http://localhost:8081 (after port-forward)
Username: admin
Password: $ADMIN_PASSWORD

Port-forward command:
kubectl port-forward svc/kargo-api -n kargo 8081:443
EOF
    
    echo -e "\n\033[1;32mCredentials saved to: $CREDS_FILE\033[0m"
fi

echo -e "\n\033[1;33mTo access Kargo UI, run:\033[0m"
echo -e "  kubectl port-forward svc/kargo-api -n kargo 8081:443"
echo -e "  Then navigate to: http://localhost:8081"

kubectl get pods -n kargo
