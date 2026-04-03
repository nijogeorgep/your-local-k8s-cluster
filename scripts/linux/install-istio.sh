#!/bin/bash
# Install Istio on the kind cluster

ISTIO_VERSION="${1:-1.23.2}"

echo -e "\033[1;36mInstalling Istio $ISTIO_VERSION...\033[0m"

# Check if Istio is already installed
if kubectl get namespace istio-system &> /dev/null; then
    echo -e "\033[1;32m✓ Istio is already installed\033[0m"
    
    # Check if it's running
    if kubectl get pods -n istio-system -l app=istiod --field-selector=status.phase=Running &> /dev/null; then
        echo -e "  Istiod is running"
        ISTIO_IMG=$(kubectl get deployment -n istio-system istiod -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
        echo -e "  Version: $ISTIO_IMG"
    else
        echo -e "  \033[1;33mWARNING: Istio namespace exists but pods are not running\033[0m"
    fi
    
    # Verify sidecar injection on default namespace
    INJECTION_LABEL=$(kubectl get namespace default -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null)
    if [[ "$INJECTION_LABEL" == "enabled" ]]; then
        echo -e "  Sidecar injection: enabled on default namespace"
    else
        echo -e "  \033[1;33mEnabling sidecar injection for default namespace...\033[0m"
        kubectl label namespace default istio-injection=enabled --overwrite
    fi
    
    kubectl get pods -n istio-system
    exit 0
fi

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux*)
        OS_TYPE="linux"
        ;;
    Darwin*)
        OS_TYPE="osx"
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

# Download istioctl if not present
ISTIO_DIR="./tools/istio-$ISTIO_VERSION"
if [[ ! -d "$ISTIO_DIR" ]]; then
    echo -e "\033[1;33mDownloading Istio...\033[0m"
    DOWNLOAD_URL="https://github.com/istio/istio/releases/download/$ISTIO_VERSION/istio-$ISTIO_VERSION-$OS_TYPE-$ARCH_TYPE.tar.gz"
    TAR_FILE="./tools/istio-$ISTIO_VERSION.tar.gz"
    
    mkdir -p ./tools
    curl -L "$DOWNLOAD_URL" -o "$TAR_FILE"
    tar -xzf "$TAR_FILE" -C ./tools
    rm "$TAR_FILE"
fi

ISTIOCTL="$ISTIO_DIR/bin/istioctl"
chmod +x "$ISTIOCTL"

# Install Istio with default profile
echo -e "\033[1;33mInstalling Istio to cluster...\033[0m"
"$ISTIOCTL" install --set profile=demo -y

# Label default namespace for sidecar injection
echo -e "\033[1;33mEnabling sidecar injection for default namespace...\033[0m"
kubectl label namespace default istio-injection=enabled --overwrite

# Verify installation
echo -e "\n\033[1;33mVerifying Istio installation...\033[0m"
kubectl get pods -n istio-system

echo -e "\n\033[1;32mIstio installed successfully!\033[0m"
echo -e "\033[1;32mistioctl available at: $ISTIOCTL\033[0m"
