#!/bin/bash
# Generate a new token for Kubernetes Dashboard access

SERVICE_ACCOUNT="admin-user"
NAMESPACE="kubernetes-dashboard"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --service-account)
            SERVICE_ACCOUNT="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--service-account <name>] [--namespace <ns>]"
            exit 1
            ;;
    esac
done

echo -e "\033[1;36mGenerating token for service account '$SERVICE_ACCOUNT' in namespace '$NAMESPACE'...\033[0m"

# Check if service account exists
if ! kubectl get serviceaccount "$SERVICE_ACCOUNT" -n "$NAMESPACE" &> /dev/null; then
    echo -e "\033[1;31mERROR: Service account '$SERVICE_ACCOUNT' not found in namespace '$NAMESPACE'\033[0m"
    echo -e "\033[1;33mRun ./scripts/linux/install-dashboard.sh first to create the dashboard and service account\033[0m"
    exit 1
fi

# Check if secret exists
if ! kubectl get secret "$SERVICE_ACCOUNT-token" -n "$NAMESPACE" &> /dev/null; then
    echo -e "\033[1;33mToken secret not found. Creating new secret...\033[0m"
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: $SERVICE_ACCOUNT-token
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/service-account.name: $SERVICE_ACCOUNT
type: kubernetes.io/service-account-token
EOF
    
    sleep 3
fi

# Get the token
TOKEN=$(kubectl get secret "$SERVICE_ACCOUNT-token" -n "$NAMESPACE" -o jsonpath="{.data.token}" 2>/dev/null | base64 -d)
if [[ -z "$TOKEN" ]]; then
    # For Kubernetes 1.24+, create a temporary token
    echo -e "\033[1;33mUsing kubectl create token (Kubernetes 1.24+)...\033[0m"
    TOKEN=$(kubectl create token "$SERVICE_ACCOUNT" -n "$NAMESPACE" --duration=87600h)
fi

echo -e "\n\033[1;32mAccess Token for '$SERVICE_ACCOUNT':\033[0m"
echo -e "\033[1;37m$TOKEN\033[0m"

# Save to file
CREDS_DIR="./credentials/service-accounts"
mkdir -p "$CREDS_DIR"
CREDS_FILE="$CREDS_DIR/$SERVICE_ACCOUNT-$NAMESPACE.txt"

cat > "$CREDS_FILE" << EOF
Kubernetes Dashboard Access Token
==================================
Created: $(date '+%Y-%m-%d %H:%M:%S')

Service Account: $SERVICE_ACCOUNT
Namespace: $NAMESPACE

Token:
$TOKEN

Access Instructions:
--------------------
1. Start kubectl proxy:
   kubectl proxy

2. Open browser to:
   http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/

3. Select "Token" authentication method

4. Paste the token above
EOF

echo -e "\n\033[1;32mToken saved to: $CREDS_FILE\033[0m"

echo -e "\n\033[1;33mAccess Instructions:\033[0m"
echo -e "  1. Start kubectl proxy:"
echo -e "     kubectl proxy"
echo -e "  2. Open browser:"
echo -e "     http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo -e "  3. Use token from: $CREDS_FILE"

# Try to copy to clipboard if available
if command -v xclip &> /dev/null; then
    echo "$TOKEN" | xclip -selection clipboard
    echo -e "\n\033[1;32m✓ Token copied to clipboard (xclip)\033[0m"
elif command -v pbcopy &> /dev/null; then
    echo "$TOKEN" | pbcopy
    echo -e "\n\033[1;32m✓ Token copied to clipboard (pbcopy)\033[0m"
else
    echo -e "\n\033[1;33m! Clipboard utility not available (install xclip or pbcopy)\033[0m"
fi
