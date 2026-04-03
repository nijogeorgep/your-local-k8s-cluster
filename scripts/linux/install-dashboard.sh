#!/bin/bash
# Install Kubernetes Dashboard on the kind cluster

echo -e "\033[1;36mInstalling Kubernetes Dashboard...\033[0m"

# Check if Dashboard is already installed
if kubectl get namespace kubernetes-dashboard &> /dev/null; then
    echo -e "\033[1;32m✓ Kubernetes Dashboard is already installed\033[0m"
    
    # Check if pods are running
    if kubectl get pods -n kubernetes-dashboard --field-selector=status.phase=Running &> /dev/null; then
        echo -e "  Dashboard pods are running"
        kubectl get pods -n kubernetes-dashboard
    else
        echo -e "  \033[1;33mWARNING: Dashboard namespace exists but pods are not running\033[0m"
        kubectl get pods -n kubernetes-dashboard
    fi
    
    # Check for admin-user service account
    if kubectl get serviceaccount admin-user -n kubernetes-dashboard &> /dev/null; then
        echo -e "  Service account 'admin-user' exists"
        
        # Get token
        TOKEN_FILE="./credentials/service-accounts/admin-user-kubernetes-dashboard.txt"
        if [[ -f "$TOKEN_FILE" ]]; then
            echo -e "  Token file: $TOKEN_FILE"
        fi
    fi
    
    echo -e "\n  \033[1;33mTo access Dashboard:\033[0m"
    echo -e "    kubectl proxy"
    echo -e "    http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
    exit 0
fi

# Install Dashboard
echo -e "\033[1;33mInstalling Dashboard components...\033[0m"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

# Create service account
echo -e "\033[1;33mCreating admin service account...\033[0m"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: v1
kind: Secret
metadata:
  name: admin-user-token
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/service-account.name: admin-user
type: kubernetes.io/service-account-token
EOF

# Wait for Dashboard to be ready
echo -e "\033[1;33mWaiting for Dashboard pods to be ready...\033[0m"
kubectl wait --for=condition=Ready pods --all -n kubernetes-dashboard --timeout=300s

# Wait for token to be generated
sleep 3

# Get the token
TOKEN=$(kubectl get secret admin-user-token -n kubernetes-dashboard -o jsonpath="{.data.token}" 2>/dev/null | base64 -d)
if [[ -z "$TOKEN" ]]; then
    # For Kubernetes 1.24+
    TOKEN=$(kubectl create token admin-user -n kubernetes-dashboard --duration=87600h)
fi

echo -e "\n\033[1;32mKubernetes Dashboard installed successfully!\033[0m"

# Save token to file
CREDS_DIR="./credentials/service-accounts"
mkdir -p "$CREDS_DIR"
CREDS_FILE="$CREDS_DIR/admin-user-kubernetes-dashboard.txt"

cat > "$CREDS_FILE" << EOF
Kubernetes Dashboard Access Token
==================================
Created: $(date '+%Y-%m-%d %H:%M:%S')

Service Account: admin-user
Namespace: kubernetes-dashboard
Role: cluster-admin

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

Alternative access with port-forward:
kubectl port-forward -n kubernetes-dashboard service/kubernetes-dashboard 8443:443
https://localhost:8443
EOF

echo -e "\033[1;32mToken saved to: $CREDS_FILE\033[0m"

echo -e "\n\033[1;33mTo access Dashboard:\033[0m"
echo -e "  1. Start kubectl proxy:"
echo -e "     kubectl proxy"
echo -e "  2. Open browser:"
echo -e "     http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo -e "  3. Use token from: $CREDS_FILE"

echo -e "\n\033[1;36mAccess Token:\033[0m"
echo -e "$TOKEN"
