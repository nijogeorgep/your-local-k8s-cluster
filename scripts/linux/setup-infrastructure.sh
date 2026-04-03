#!/bin/bash
# Setup infrastructure resources (cert-issuers, gateways, etc.)

echo -e "\033[1;36mSetting up infrastructure resources...\033[0m"

MANIFESTS_DIR="./manifests/infrastructure"

if [[ ! -d "$MANIFESTS_DIR" ]]; then
    echo -e "\033[1;33mWARNING: Infrastructure manifests directory not found: $MANIFESTS_DIR\033[0m"
    echo -e "Skipping infrastructure setup."
    exit 0
fi

# Check if Istio is installed (required for gateway)
if ! kubectl get namespace istio-system &> /dev/null; then
    echo -e "\033[1;33mWARNING: Istio is not installed. Skipping Istio gateway setup.\033[0m"
    SKIP_ISTIO=true
else
    SKIP_ISTIO=false
fi

# Check if cert-manager is installed (required for cert-issuers)
if ! kubectl get namespace cert-manager &> /dev/null; then
    echo -e "\033[1;33mWARNING: cert-manager is not installed. Skipping certificate issuers setup.\033[0m"
    SKIP_CERT=true
else
    SKIP_CERT=false
fi

# Apply cert-issuers if cert-manager is installed
if [[ "$SKIP_CERT" == "false" ]] && [[ -f "$MANIFESTS_DIR/cert-issuers.yaml" ]]; then
    echo -e "\033[1;33mApplying certificate issuers...\033[0m"
    kubectl apply -f "$MANIFESTS_DIR/cert-issuers.yaml"
fi

# Apply Istio gateway if Istio is installed
if [[ "$SKIP_ISTIO" == "false" ]] && [[ -f "$MANIFESTS_DIR/istio-gateway.yaml" ]]; then
    echo -e "\033[1;33mApplying Istio gateway...\033[0m"
    kubectl apply -f "$MANIFESTS_DIR/istio-gateway.yaml"
fi

# Apply cluster certificate if available
if [[ -f "$MANIFESTS_DIR/cluster-certificate.yaml" ]]; then
    echo -e "\033[1;33mApplying cluster certificate...\033[0m"
    kubectl apply -f "$MANIFESTS_DIR/cluster-certificate.yaml"
fi

# Apply tools routing if available
if [[ -f "$MANIFESTS_DIR/tools-routing.yaml" ]]; then
    echo -e "\033[1;33mApplying tools routing...\033[0m"
    kubectl apply -f "$MANIFESTS_DIR/tools-routing.yaml"
fi

echo -e "\n\033[1;32mInfrastructure setup complete!\033[0m"
