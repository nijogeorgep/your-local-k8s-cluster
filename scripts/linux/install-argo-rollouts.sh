#!/bin/bash
# Install Argo Rollouts on the kind cluster

VERSION="${1:-stable}"

echo -e "\033[1;36mInstalling Argo Rollouts ($VERSION)...\033[0m"

# Check if Argo Rollouts is already installed
if kubectl get namespace argo-rollouts &> /dev/null; then
    echo -e "\033[1;32m✓ Argo Rollouts is already installed\033[0m"
    
    # Check if pods are running
    if kubectl get pods -n argo-rollouts --field-selector=status.phase=Running &> /dev/null; then
        echo -e "  Argo Rollouts controller is running"
        kubectl get pods -n argo-rollouts
    else
        echo -e "  \033[1;33mWARNING: Argo Rollouts namespace exists but pods are not running\033[0m"
        kubectl get pods -n argo-rollouts
    fi
    
    # Check kubectl plugin
    PLUGIN_PATH="./tools/kubectl-plugins/kubectl-argo-rollouts"
    if [[ -f "$PLUGIN_PATH" ]]; then
        echo -e "  kubectl plugin: $PLUGIN_PATH"
    fi
    
    exit 0
fi

# Create namespace
echo -e "\033[1;33mCreating argo-rollouts namespace...\033[0m"
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -

# Install Argo Rollouts
echo -e "\033[1;33mInstalling Argo Rollouts components...\033[0m"
kubectl apply -n argo-rollouts -f "https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml"

# Wait for Argo Rollouts to be ready
echo -e "\033[1;33mWaiting for Argo Rollouts pods to be ready...\033[0m"
kubectl wait --for=condition=Ready pods --all -n argo-rollouts --timeout=300s

# Download kubectl plugin
echo -e "\n\033[1;33mDownloading kubectl-argo-rollouts plugin...\033[0m"

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux*)
        OS_TYPE="linux"
        ;;
    Darwin*)
        OS_TYPE="darwin"
        ;;
    *)
        echo -e "\033[1;31mUnsupported OS: $OS\033[0m"
        exit 1
        ;;
esac

case "$ARCH" in
    x86_64)
        ARCH_TYPE="amd64"
        ;;
    aarch64|arm64)
        ARCH_TYPE="arm64"
        ;;
    *)
        echo -e "\033[1;31mUnsupported architecture: $ARCH\033[0m"
        exit 1
        ;;
esac

PLUGIN_DIR="./tools/kubectl-plugins"
mkdir -p "$PLUGIN_DIR"

DOWNLOAD_URL="https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-$OS_TYPE-$ARCH_TYPE"
PLUGIN_PATH="$PLUGIN_DIR/kubectl-argo-rollouts"

curl -L "$DOWNLOAD_URL" -o "$PLUGIN_PATH"
chmod +x "$PLUGIN_PATH"

echo -e "\n\033[1;32mArgo Rollouts installed successfully!\033[0m"
echo -e "\033[1;32mkubectl plugin available at: $PLUGIN_PATH\033[0m"

echo -e "\n\033[1;33mUsage:\033[0m"
echo -e "  \033[1;36mView rollouts:\033[0m"
echo -e "    kubectl argo rollouts list rollouts -n <namespace>"
echo -e "  \033[1;36mStart dashboard:\033[0m"
echo -e "    $PLUGIN_PATH dashboard"
echo -e "  \033[1;36mGet rollout status:\033[0m"
echo -e "    kubectl argo rollouts get rollout <rollout-name> -n <namespace>"
