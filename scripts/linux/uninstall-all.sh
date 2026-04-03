#!/bin/bash
# Uninstall all tools from the cluster

FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo -e "\033[1;33mUninstalling all tools from the cluster...\033[0m"

if [[ "$FORCE" != "true" ]]; then
    read -p "This will remove Istio, ArgoCD, Argo Rollouts, Kargo, cert-manager, and Dashboard. Continue? (yes/no) " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo -e "\033[1;36mUninstallation cancelled.\033[0m"
        exit 0
    fi
fi

# Uninstall Dashboard
echo -e "\n\033[1;33mUninstalling Kubernetes Dashboard...\033[0m"
kubectl delete namespace kubernetes-dashboard 2>/dev/null
kubectl delete clusterrolebinding admin-user 2>/dev/null

# Uninstall Kargo
echo -e "\033[1;33mUninstalling Kargo...\033[0m"
helm uninstall kargo -n kargo 2>/dev/null
kubectl delete namespace kargo 2>/dev/null

# Uninstall Argo Rollouts
echo -e "\033[1;33mUninstalling Argo Rollouts...\033[0m"
kubectl delete namespace argo-rollouts 2>/dev/null

# Uninstall ArgoCD
echo -e "\033[1;33mUninstalling ArgoCD...\033[0m"
kubectl delete namespace argocd 2>/dev/null

# Uninstall Istio
echo -e "\033[1;33mUninstalling Istio...\033[0m"
ISTIOCTL=$(find ./tools -name istioctl -type f 2>/dev/null | head -n 1)
if [[ -n "$ISTIOCTL" ]]; then
    "$ISTIOCTL" uninstall --purge -y 2>/dev/null
fi
kubectl delete namespace istio-system 2>/dev/null

# Uninstall cert-manager
echo -e "\033[1;33mUninstalling cert-manager...\033[0m"
kubectl delete namespace cert-manager 2>/dev/null

# Remove labels from default namespace
echo -e "\033[1;33mCleaning up default namespace labels...\033[0m"
kubectl label namespace default istio-injection- 2>/dev/null

echo -e "\n\033[1;32mAll tools uninstalled successfully!\033[0m"
