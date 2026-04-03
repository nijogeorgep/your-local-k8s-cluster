#!/bin/bash
# Delete specific namespaces from the cluster

# Default namespaces to delete
DEFAULT_NAMESPACES=(
    "spring-kotlin-app"
    "spring-kotlin-app-project"
    "kubernetes-dashboard"
    "kargo"
    "argo-rollouts"
    "argocd"
    "istio-system"
    "cert-manager"
)

FORCE=false
TIMEOUT=60
NAMESPACES=()

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --namespaces)
            IFS=',' read -ra NAMESPACES <<< "$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--force] [--timeout <seconds>] [--namespaces <ns1,ns2,...>]"
            exit 1
            ;;
    esac
done

# Use default namespaces if none specified
if [[ ${#NAMESPACES[@]} -eq 0 ]]; then
    NAMESPACES=("${DEFAULT_NAMESPACES[@]}")
fi

cat << "EOF"
╔═══════════════════════════════════════════════╗
║       Namespace Cleanup                       ║
║  Delete specified namespaces from cluster     ║
╚═══════════════════════════════════════════════╝
EOF

# Check if cluster is accessible
echo -e "\n\033[1;33mChecking cluster connectivity...\033[0m"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "\033[1;31m✗ Cannot connect to cluster\033[0m"
    echo -e "\033[1;33m  Make sure your Kubernetes cluster is running\033[0m"
    exit 1
fi
echo -e "\033[1;32m✓ Cluster is accessible\033[0m"

# Show current namespaces
echo -e "\n\033[1;36mCurrent namespaces:\033[0m"
kubectl get namespaces

# Confirm deletion
if [[ "$FORCE" != "true" ]]; then
    echo -e "\n\033[1;33m⚠️  The following namespaces will be deleted:\033[0m"
    for ns in "${NAMESPACES[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            echo -e "  • $ns"
        else
            echo -e "\033[0;37m  • $ns (not found)\033[0m"
        fi
    done
    
    read -p $'\nContinue? (y/n) ' confirm
    if [[ "$confirm" != "y" ]]; then
        echo -e "\n\033[1;36m✓ Cleanup cancelled.\033[0m"
        exit 0
    fi
fi

# Delete namespaces
echo -e "\n\033[1;36m════════════════════════════════════════════════\033[0m"
echo -e "\033[1;36mDeleting Namespaces\033[0m"
echo -e "\033[1;36m════════════════════════════════════════════════\033[0m"

DELETED=()
NOT_FOUND=()
FAILED=()

for ns in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &> /dev/null; then
        echo -e "\n\033[1;33mDeleting namespace: $ns\033[0m"
        if kubectl delete namespace "$ns" --timeout="${TIMEOUT}s" &> /dev/null; then
            echo -e "  \033[1;32m✓ Deleted successfully\033[0m"
            DELETED+=("$ns")
        else
            echo -e "  \033[1;33m⚠️  Deletion initiated (may be terminating)\033[0m"
            FAILED+=("$ns")
        fi
    else
        echo -e "  \033[0;37m- Namespace '$ns' not found\033[0m"
        NOT_FOUND+=("$ns")
    fi
done

# Wait for terminating namespaces
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo -e "\n\033[1;36mWaiting for terminating namespaces to complete...\033[0m"
    sleep 5
fi

# Show final status
echo -e "\n\033[1;32m════════════════════════════════════════════════\033[0m"
echo -e "\033[1;32mCleanup Complete\033[0m"
echo -e "\033[1;32m════════════════════════════════════════════════\033[0m"

echo -e "\n\033[1;36m📊 Summary:\033[0m"

if [[ ${#DELETED[@]} -gt 0 ]]; then
    echo -e "\n\033[1;32m✓ Successfully deleted (${#DELETED[@]}):\033[0m"
    for ns in "${DELETED[@]}"; do
        echo -e "  • $ns"
    done
fi

if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo -e "\n\033[1;33m⏳ Terminating (${#FAILED[@]}):\033[0m"
    for ns in "${FAILED[@]}"; do
        echo -e "  • $ns"
    done
    echo -e "\n\033[1;36m💡 Note: These namespaces are being deleted in the background.\033[0m"
    echo -e "\033[1;36m   Resources with finalizers may take a few minutes to clean up.\033[0m"
fi

if [[ ${#NOT_FOUND[@]} -gt 0 ]]; then
    echo -e "\n\033[0;37m- Not found (${#NOT_FOUND[@]}):\033[0m"
    for ns in "${NOT_FOUND[@]}"; do
        echo -e "\033[0;37m  • $ns\033[0m"
    done
fi

echo -e "\n\033[1;36mFinal namespaces:\033[0m"
kubectl get namespaces

echo -e "\n\033[1;32m✅ Cleanup script completed!\033[0m\n"
