#!/bin/bash
# Complete teardown: Delete all deployments, uninstall tools, delete cluster, clean files

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
FORCE=false
KEEP_CLUSTER=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)   FORCE=true; shift ;;
        --keep-cluster) KEEP_CLUSTER=true; shift ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

# Colors
RED='\033[1;31m'; YELLOW='\033[1;33m'; GREEN='\033[1;32m'; CYAN='\033[1;36m'; WHITE='\033[1;37m'; NC='\033[0m'

echo -e "${YELLOW}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║       Complete Teardown                       ║${NC}"
echo -e "${YELLOW}║  - Delete all deployments                     ║${NC}"
echo -e "${YELLOW}║  - Uninstall all tools                        ║${NC}"
echo -e "${YELLOW}║  - Delete kind cluster                        ║${NC}"
echo -e "${YELLOW}║  - Clean local files                          ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════╝${NC}"

if [[ "$FORCE" != "true" ]]; then
    echo -e "\n${RED}⚠️  WARNING: This will:${NC}"
    echo -e "${YELLOW}   • Delete all Helm deployments (spring-kotlin-app, etc.)${NC}"
    echo -e "${YELLOW}   • Uninstall all tools (Istio, ArgoCD, Kargo, Dashboard, etc.)${NC}"
    echo -e "${YELLOW}   • Delete the kind cluster 'my-local-cluster'${NC}"
    echo -e "${YELLOW}   • Remove tools/ and credentials/ directories${NC}"

    read -rp $'\nType \'DELETE\' to confirm: ' confirm
    if [[ "$confirm" != "DELETE" ]]; then
        echo -e "\n${CYAN}✓ Teardown cancelled.${NC}"
        exit 0
    fi
fi

# Step 1: Delete all Helm deployments
echo -e "\n${CYAN}════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 1/5: Deleting Helm Deployments${NC}"
echo -e "${CYAN}════════════════════════════════════════════════${NC}"

CLUSTER_ACCESSIBLE=false
if kubectl cluster-info &>/dev/null 2>&1; then
    CLUSTER_ACCESSIBLE=true
else
    echo -e "${YELLOW}⚠️  Cluster not accessible, skipping deployments cleanup${NC}"
fi

if [[ "$CLUSTER_ACCESSIBLE" == "true" ]]; then
    HELM_RELEASES=$(helm list --all-namespaces -o json 2>/dev/null || echo "[]")

    if [[ "$HELM_RELEASES" != "[]" ]] && [[ -n "$HELM_RELEASES" ]]; then
        RELEASE_COUNT=$(echo "$HELM_RELEASES" | jq '. | length')
        echo -e "\n${YELLOW}Found ${RELEASE_COUNT} Helm release(s):${NC}"
        echo "$HELM_RELEASES" | jq -r '.[] | "  • \(.name) (namespace: \(.namespace))"'

        echo -e "\n${YELLOW}Deleting Helm releases...${NC}"
        while IFS= read -r line; do
            name=$(echo "$line" | cut -d'|' -f1)
            ns=$(echo "$line" | cut -d'|' -f2)
            echo -e "  ${CYAN}Deleting: ${name} from namespace ${ns}...${NC}"
            if helm uninstall "$name" -n "$ns" 2>/dev/null; then
                echo -e "    ${GREEN}✓ Deleted${NC}"
            else
                echo -e "    ${YELLOW}⚠️  Failed or already deleted${NC}"
            fi
        done < <(echo "$HELM_RELEASES" | jq -r '.[] | "\(.name)|\(.namespace)"')
    else
        echo -e "${GREEN}✓ No Helm releases found${NC}"
    fi

    # Delete application namespaces
    echo -e "\n${YELLOW}Deleting application namespaces...${NC}"
    for ns in spring-kotlin-app spring-kotlin-app-project; do
        if kubectl get namespace "$ns" --ignore-not-found=true 2>/dev/null | grep -q "$ns"; then
            echo -e "  ${CYAN}Deleting namespace: ${ns}...${NC}"
            if kubectl delete namespace "$ns" --timeout=60s 2>/dev/null; then
                echo -e "    ${GREEN}✓ Deleted${NC}"
            else
                echo -e "    ${YELLOW}⚠️  Failed or timed out${NC}"
            fi
        fi
    done
fi

# Step 2: Uninstall all tools
echo -e "\n${CYAN}════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 2/5: Uninstalling Tools${NC}"
echo -e "${CYAN}════════════════════════════════════════════════${NC}"

if [[ "$CLUSTER_ACCESSIBLE" == "true" ]]; then
    bash "$SCRIPT_DIR/uninstall-all.sh" --force
else
    echo -e "${YELLOW}⚠️  Skipping tool uninstallation (cluster not accessible)${NC}"
fi

# Step 3: Delete cluster
if [[ "$KEEP_CLUSTER" != "true" ]]; then
    echo -e "\n${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Step 3/5: Deleting Kind Cluster${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"

    if kind get clusters 2>/dev/null | grep -q "my-local-cluster"; then
        echo -e "${YELLOW}Deleting kind cluster 'my-local-cluster'...${NC}"
        if kind delete cluster --name my-local-cluster; then
            echo -e "${GREEN}✓ Cluster deleted${NC}"
        else
            echo -e "${YELLOW}⚠️  Failed to delete cluster${NC}"
        fi
    else
        echo -e "${GREEN}✓ Cluster 'my-local-cluster' not found${NC}"
    fi
else
    echo -e "\n${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Step 3/5: Keeping Cluster (--keep-cluster)${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
fi

# Step 4: Clean tools directory
echo -e "\n${CYAN}════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 4/5: Cleaning Tools Directory${NC}"
echo -e "${CYAN}════════════════════════════════════════════════${NC}"

TOOLS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/tools"
if [[ -d "$TOOLS_DIR" ]]; then
    echo -e "${YELLOW}Removing tools directory...${NC}"
    if rm -rf "$TOOLS_DIR"; then
        echo -e "${GREEN}✓ Removed tools/${NC}"
    else
        echo -e "${YELLOW}⚠️  Failed to remove tools/${NC}"
    fi
else
    echo -e "${GREEN}✓ Tools directory not found${NC}"
fi

# Step 5: Clean credentials directory
echo -e "\n${CYAN}════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 5/5: Cleaning Credentials Directory${NC}"
echo -e "${CYAN}════════════════════════════════════════════════${NC}"

CREDS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/credentials"
if [[ -d "$CREDS_DIR" ]]; then
    echo -e "${YELLOW}Removing credentials directory...${NC}"
    if rm -rf "$CREDS_DIR"; then
        echo -e "${GREEN}✓ Removed credentials/${NC}"
    else
        echo -e "${YELLOW}⚠️  Failed to remove credentials/${NC}"
    fi
else
    echo -e "${GREEN}✓ Credentials directory not found${NC}"
fi

# Summary
echo -e "\n${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Teardown Complete!                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"

echo -e "\n${GREEN}✓ Completed:${NC}"
echo -e "${WHITE}  • Deleted all Helm deployments${NC}"
echo -e "${WHITE}  • Uninstalled all tools${NC}"
if [[ "$KEEP_CLUSTER" != "true" ]]; then
    echo -e "${WHITE}  • Deleted kind cluster${NC}"
fi
echo -e "${WHITE}  • Cleaned tools/ directory${NC}"
echo -e "${WHITE}  • Cleaned credentials/ directory${NC}"

echo -e "\n${CYAN}To recreate the cluster:${NC}"
echo -e "${WHITE}  ./build.sh setup${NC}"
echo -e "${YELLOW}  or${NC}"
echo -e "${WHITE}  make setup${NC}"
echo ""
