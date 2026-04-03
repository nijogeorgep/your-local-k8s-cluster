#!/bin/bash
# Verify cluster status and installed components

echo -e "\033[1;36mKubernetes Cluster Status\033[0m"
echo -e "\033[1;36m═══════════════════════════════════════════════\033[0m\n"

# Cluster info
echo -e "\033[1;33mCluster Information:\033[0m"
kubectl cluster-info
echo ""

# Node status
echo -e "\033[1;33mNodes:\033[0m"
kubectl get nodes -o wide
echo ""

# Check installed components
echo -e "\033[1;33mInstalled Components:\033[0m"

NAMESPACES=$(kubectl get namespaces -o json)

# cert-manager
if echo "$NAMESPACES" | jq -r '.items[].metadata.name' | grep -q "^cert-manager$"; then
    echo -e "  \033[1;32m✓ cert-manager\033[0m"
    kubectl get pods -n cert-manager
    echo ""
fi

# Istio
if echo "$NAMESPACES" | jq -r '.items[].metadata.name' | grep -q "^istio-system$"; then
    ISTIO_VERSION=$(kubectl get deployment -n istio-system istiod -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
    echo -e "  \033[1;32m✓ Istio: $ISTIO_VERSION\033[0m"
    kubectl get pods -n istio-system
    echo ""
fi

# ArgoCD
if echo "$NAMESPACES" | jq -r '.items[].metadata.name' | grep -q "^argocd$"; then
    echo -e "  \033[1;32m✓ ArgoCD\033[0m"
    kubectl get pods -n argocd
    echo ""
fi

# Argo Rollouts
if echo "$NAMESPACES" | jq -r '.items[].metadata.name' | grep -q "^argo-rollouts$"; then
    echo -e "  \033[1;32m✓ Argo Rollouts\033[0m"
    kubectl get pods -n argo-rollouts
    echo ""
fi

# Kargo
if echo "$NAMESPACES" | jq -r '.items[].metadata.name' | grep -q "^kargo$"; then
    echo -e "  \033[1;32m✓ Kargo\033[0m"
    kubectl get pods -n kargo
    echo ""
fi

# Kubernetes Dashboard
if echo "$NAMESPACES" | jq -r '.items[].metadata.name' | grep -q "^kubernetes-dashboard$"; then
    echo -e "  \033[1;32m✓ Kubernetes Dashboard\033[0m"
    kubectl get pods -n kubernetes-dashboard
    echo ""
fi

# Summary
echo -e "\n\033[1;36m═══════════════════════════════════════════════\033[0m"
echo -e "\033[1;32mCluster verification complete!\033[0m"
