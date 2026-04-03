#!/bin/bash
# Install ArgoCD on the kind cluster

VERSION="${1:-stable}"

echo -e "\033[1;36mInstalling ArgoCD ($VERSION)...\033[0m"

# Check if ArgoCD is already installed
if kubectl get namespace argocd &> /dev/null; then
    echo -e "\033[1;32m✓ ArgoCD is already installed\033[0m"
    
    # Check if pods are running
    if kubectl get pods -n argocd --field-selector=status.phase=Running &> /dev/null; then
        echo -e "  ArgoCD pods are running"
        kubectl get pods -n argocd
    else
        echo -e "  \033[1;33mWARNING: ArgoCD namespace exists but pods are not all running\033[0m"
        kubectl get pods -n argocd
    fi
    
    # Get admin password if available
    if kubectl get secret argocd-initial-admin-secret -n argocd &> /dev/null; then
        ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
        echo -e "\n  Username: admin"
        echo -e "  Password: $ADMIN_PASSWORD"
        
        # Update credentials file
        CREDS_FILE="./credentials/argocd-credentials.txt"
        if [[ ! -f "$CREDS_FILE" ]]; then
            mkdir -p ./credentials
            cat > "$CREDS_FILE" << EOF
ArgoCD Credentials
==================
URL: https://localhost:8080 (after port-forward)
Username: admin
Password: $ADMIN_PASSWORD

Port-forward command:
kubectl port-forward svc/argocd-server -n argocd 8080:443
EOF
            echo -e "\n  Credentials saved to: $CREDS_FILE"
        fi
    fi
    
    echo -e "\n  \033[1;33mTo access ArgoCD UI:\033[0m"
    echo -e "    kubectl port-forward svc/argocd-server -n argocd 8080:443"
    exit 0
fi

# Create namespace
echo -e "\033[1;33mCreating argocd namespace...\033[0m"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo -e "\033[1;33mInstalling ArgoCD components...\033[0m"
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/$VERSION/manifests/install.yaml"

# Wait for ArgoCD to be ready
echo -e "\033[1;33mWaiting for ArgoCD pods to be ready...\033[0m"
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get initial admin password
echo -e "\n\033[1;33mRetrieving initial admin password...\033[0m"
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo -e "\n\033[1;32mArgoCD installed successfully!\033[0m"
echo -e "\033[1;36mUsername:\033[0m admin"
echo -e "\033[1;36mPassword:\033[0m $ADMIN_PASSWORD"
echo -e "\n\033[1;33mTo access ArgoCD UI, run:\033[0m"
echo -e "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo -e "  Then navigate to: https://localhost:8080"

# Save credentials to file
CREDS_FILE="./credentials/argocd-credentials.txt"
mkdir -p ./credentials

cat > "$CREDS_FILE" << EOF
ArgoCD Credentials
==================
URL: https://localhost:8080 (after port-forward)
Username: admin
Password: $ADMIN_PASSWORD

Port-forward command:
kubectl port-forward svc/argocd-server -n argocd 8080:443

Login with argocd CLI:
argocd login localhost:8080 --username admin --password $ADMIN_PASSWORD --insecure
EOF

echo -e "\n\033[1;32mCredentials saved to: $CREDS_FILE\033[0m"
