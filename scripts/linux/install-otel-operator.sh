#!/bin/bash
# Install OpenTelemetry Operator on the kind cluster
# Manages OpenTelemetryCollector and Instrumentation CRs; uses cert-manager for webhook TLS

VERSION="${1:-}"

echo -e "\033[1;36mInstalling OpenTelemetry Operator...\033[0m"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# cert-manager is required for admission webhook TLS
echo -e "\033[1;33mChecking cert-manager prerequisite...\033[0m"
bash "$SCRIPT_DIR/install-cert-manager.sh"
if [[ $? -ne 0 ]]; then
    echo -e "\033[1;31mERROR: cert-manager installation failed\033[0m"
    exit 1
fi

# Idempotency check
if kubectl get namespace opentelemetry-operator &>/dev/null; then
    if kubectl get deployments -n opentelemetry-operator &>/dev/null 2>&1 | grep -q .; then
        echo -e "\033[1;32m✓ OpenTelemetry Operator is already installed\033[0m"

        if kubectl get pods -n opentelemetry-operator --field-selector=status.phase=Running &>/dev/null; then
            echo -e "  Pods are running"
            kubectl get pods -n opentelemetry-operator
        else
            echo -e "  \033[1;33mWARNING: opentelemetry-operator namespace exists but pods may not be running\033[0m"
            kubectl get pods -n opentelemetry-operator
        fi

        exit 0
    fi
fi

# Create namespace
echo -e "\033[1;33mCreating opentelemetry-operator namespace...\033[0m"
kubectl create namespace opentelemetry-operator --dry-run=client -o yaml | kubectl apply -f -

# Add / refresh Helm repo
echo -e "\033[1;33mAdding open-telemetry Helm repository...\033[0m"
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts 2>/dev/null || true
helm repo update open-telemetry

# Build install command
HELM_ARGS=(
    install opentelemetry-operator open-telemetry/opentelemetry-operator
    --namespace opentelemetry-operator
    --set manager.collectorImage.repository=otel/opentelemetry-collector-k8s
    --set admissionWebhooks.certManager.enabled=true
    --wait --timeout 5m
)
if [[ -n "$VERSION" ]]; then
    HELM_ARGS+=(--version "$VERSION")
fi

echo -e "\033[1;33mInstalling OpenTelemetry Operator via Helm...\033[0m"
helm "${HELM_ARGS[@]}"
if [[ $? -ne 0 ]]; then
    echo -e "\033[1;31mERROR: Helm install failed\033[0m"
    exit 1
fi

# Verify
echo -e "\n\033[1;33mVerifying OpenTelemetry Operator installation...\033[0m"
kubectl get pods -n opentelemetry-operator

echo -e "\n\033[1;32mOpenTelemetry Operator installed successfully!\033[0m"
echo -e "\n\033[1;36mThe operator manages OpenTelemetryCollector and Instrumentation resources.\033[0m"
echo -e "Deploy an example collector:"
echo -e "  kubectl apply -f manifests/examples/otel-collector.yaml"
echo -e "List collectors:"
echo -e "  kubectl get opentelemetrycollectors -A"
