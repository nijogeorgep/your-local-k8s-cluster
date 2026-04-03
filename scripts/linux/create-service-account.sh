#!/bin/bash
# Create a custom service account with specific permissions

# Parse command line arguments
SERVICE_ACCOUNT_NAME=""
NAMESPACE="default"
ROLE="view"
CUSTOM_CLUSTER_ROLE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            SERVICE_ACCOUNT_NAME="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --role)
            ROLE="$2"
            shift 2
            ;;
        --custom-role)
            CUSTOM_CLUSTER_ROLE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 --name <sa-name> [--namespace <ns>] [--role <role>] [--custom-role <custom-role>]"
            echo "Roles: cluster-admin, admin, edit, view, custom"
            exit 1
            ;;
    esac
done

if [[ -z "$SERVICE_ACCOUNT_NAME" ]]; then
    echo -e "\033[1;31mERROR: Service account name is required\033[0m"
    echo "Usage: $0 --name <sa-name> [--namespace <ns>] [--role <role>] [--custom-role <custom-role>]"
    exit 1
fi

echo -e "\033[1;36mCreating service account '$SERVICE_ACCOUNT_NAME' in namespace '$NAMESPACE'...\033[0m"

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Create service account
echo -e "\033[1;33mCreating service account...\033[0m"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
EOF

# Determine role to use
if [[ "$ROLE" == "custom" ]] && [[ -n "$CUSTOM_CLUSTER_ROLE" ]]; then
    ROLE_TO_USE="$CUSTOM_CLUSTER_ROLE"
else
    ROLE_TO_USE="$ROLE"
fi

BINDING_NAME="$SERVICE_ACCOUNT_NAME-binding"

# Create role binding
echo -e "\033[1;33mCreating cluster role binding with role: $ROLE_TO_USE...\033[0m"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $BINDING_NAME
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: $ROLE_TO_USE
subjects:
- kind: ServiceAccount
  name: $SERVICE_ACCOUNT_NAME
  namespace: $NAMESPACE
EOF

# Create token secret
echo -e "\033[1;33mCreating token secret...\033[0m"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: $SERVICE_ACCOUNT_NAME-token
  namespace: $NAMESPACE
  annotations:
    kubernetes.io/service-account.name: $SERVICE_ACCOUNT_NAME
type: kubernetes.io/service-account-token
EOF

# Wait for token to be generated
sleep 3

# Get the token
TOKEN=$(kubectl get secret "$SERVICE_ACCOUNT_NAME-token" -n "$NAMESPACE" -o jsonpath="{.data.token}" 2>/dev/null | base64 -d)
if [[ -z "$TOKEN" ]]; then
    # For Kubernetes 1.24+
    TOKEN=$(kubectl create token "$SERVICE_ACCOUNT_NAME" -n "$NAMESPACE" --duration=87600h)
fi

echo -e "\n\033[1;32mService Account created successfully!\033[0m"
echo -e "\n\033[1;36mService Account:\033[0m $SERVICE_ACCOUNT_NAME"
echo -e "\033[1;36mNamespace:\033[0m $NAMESPACE"
echo -e "\033[1;36mRole:\033[0m $ROLE_TO_USE"

echo -e "\n\033[1;33mAccess Token:\033[0m"
echo -e "$TOKEN"

# Save to file
CREDS_DIR="./credentials/service-accounts"
mkdir -p "$CREDS_DIR"
CREDS_FILE="$CREDS_DIR/$SERVICE_ACCOUNT_NAME-$NAMESPACE.txt"

cat > "$CREDS_FILE" << EOF
Service Account Credentials
============================
Created: $(date '+%Y-%m-%d %H:%M:%S')

Service Account: $SERVICE_ACCOUNT_NAME
Namespace: $NAMESPACE
Role: $ROLE_TO_USE

Token:
$TOKEN

Usage Examples:
---------------
# Use with kubectl:
kubectl --token="$TOKEN" get pods

# Use in kubeconfig:
kubectl config set-credentials $SERVICE_ACCOUNT_NAME --token="$TOKEN"
kubectl config set-context $SERVICE_ACCOUNT_NAME-context --cluster=<cluster-name> --user=$SERVICE_ACCOUNT_NAME
kubectl config use-context $SERVICE_ACCOUNT_NAME-context

# Delete this service account:
kubectl delete serviceaccount $SERVICE_ACCOUNT_NAME -n $NAMESPACE
kubectl delete clusterrolebinding $BINDING_NAME
kubectl delete secret $SERVICE_ACCOUNT_NAME-token -n $NAMESPACE
EOF

echo -e "\n\033[1;32mCredentials saved to: $CREDS_FILE\033[0m"

echo -e "\n\033[1;33mRole Permissions:\033[0m"
case "$ROLE" in
    cluster-admin)
        echo -e "  \033[1;31mFull cluster access (use with caution!)\033[0m"
        ;;
    admin)
        echo -e "  \033[1;33mFull access to namespace resources\033[0m"
        ;;
    edit)
        echo -e "  \033[1;36mRead/write access to most resources\033[0m"
        ;;
    view)
        echo -e "  \033[1;32mRead-only access to resources\033[0m"
        ;;
    custom)
        echo -e "  \033[1;36mCustom role: $CUSTOM_CLUSTER_ROLE\033[0m"
        ;;
esac
