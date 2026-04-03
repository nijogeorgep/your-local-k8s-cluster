#!/bin/bash
#
# Spring Kotlin App Deployment Script
# Deploys nijogeorgep/spring-kotlin-app:2c5c983 with Argo Rollouts, Istio, and Kargo
#
# Usage:
#   ./deploy-spring-kotlin-app.sh                    # Interactive deployment
#   ./deploy-spring-kotlin-app.sh --non-interactive  # CI/CD friendly
#   ./deploy-spring-kotlin-app.sh --skip-checks      # Skip prerequisite checks
#   ./deploy-spring-kotlin-app.sh --uninstall        # Remove deployment
#   ./deploy-spring-kotlin-app.sh --enable-kargo     # Enable Kargo multi-environment
#   ./deploy-spring-kotlin-app.sh --wait             # Watch rollout after deploy
#   ./deploy-spring-kotlin-app.sh --namespace <ns>   # Override namespace
#   ./deploy-spring-kotlin-app.sh --release-name <n> # Override Helm release name

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VALUES_FILE="$SCRIPT_DIR/values-spring-kotlin-app.yaml"
CHART_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)/helm-charts/app-template"

# Defaults
NON_INTERACTIVE=false
SKIP_CHECKS=false
UNINSTALL=false
NAMESPACE="spring-kotlin-app"
RELEASE_NAME="spring-kotlin-app"
ENABLE_KARGO=false
WAIT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --non-interactive) NON_INTERACTIVE=true; shift ;;
        --skip-checks)     SKIP_CHECKS=true; shift ;;
        --uninstall)       UNINSTALL=true; shift ;;
        --enable-kargo)    ENABLE_KARGO=true; shift ;;
        --wait)            WAIT=true; shift ;;
        --namespace)       NAMESPACE="$2"; shift 2 ;;
        --release-name)    RELEASE_NAME="$2"; shift 2 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

# Colors
RED='\033[1;31m'; YELLOW='\033[1;33m'; GREEN='\033[1;32m'; CYAN='\033[1;36m'
MAGENTA='\033[1;35m'; WHITE='\033[1;37m'; NC='\033[0m'

log_info()    { echo -e "${CYAN}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error()   { echo -e "${RED}✗ $1${NC}"; }
log_step()    { echo -e "\n${MAGENTA}=== $1 ===${NC}"; }

show_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          Spring Kotlin App - Deployment Script                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}  Image:     nijogeorgep/spring-kotlin-app:2c5c983${NC}"
    echo -e "${WHITE}  Namespace: ${NAMESPACE}${NC}"
    echo -e "${WHITE}  Release:   ${RELEASE_NAME}${NC}"
    echo ""
}

command_exists() { command -v "$1" &>/dev/null; }

check_prerequisites() {
    log_step "Checking Prerequisites"

    local all_good=true

    # kubectl
    if command_exists kubectl; then
        log_success "kubectl is installed"
        if kubectl cluster-info &>/dev/null 2>&1; then
            log_success "Kubernetes cluster is accessible"
        else
            log_error "Cannot connect to Kubernetes cluster"
            log_info "Run: kubectl cluster-info"
            all_good=false
        fi
    else
        log_error "kubectl is not installed"
        log_info "Install from: https://kubernetes.io/docs/tasks/tools/"
        all_good=false
    fi

    # Helm
    if command_exists helm; then
        log_success "Helm is installed"
    else
        log_error "Helm is not installed"
        log_info "Install from: https://helm.sh/docs/intro/install/"
        all_good=false
    fi

    # Istio
    if kubectl get deployment -n istio-system 2>/dev/null | grep -q istiod; then
        log_success "Istio is installed"
    else
        log_warn "Istio might not be installed"
        log_info "Install with: ./scripts/linux/install-istio.sh"
        if [[ "$NON_INTERACTIVE" != "true" ]]; then
            read -rp "Continue anyway? (y/N) " cont
            [[ "$cont" == "y" || "$cont" == "Y" ]] || exit 1
        fi
    fi

    # Argo Rollouts
    if kubectl get deployment argo-rollouts -n argo-rollouts &>/dev/null 2>&1; then
        log_success "Argo Rollouts is installed"
    else
        log_warn "Argo Rollouts might not be installed"
        log_info "Install with: ./scripts/linux/install-argo-rollouts.sh"
        if [[ "$NON_INTERACTIVE" != "true" ]]; then
            read -rp "Continue anyway? (y/N) " cont
            [[ "$cont" == "y" || "$cont" == "Y" ]] || exit 1
        fi
    fi

    # Argo Rollouts kubectl plugin
    ROLLOUTS_PLUGIN="$(cd "$SCRIPT_DIR/../.." && pwd)/tools/kubectl-plugins/kubectl-argo-rollouts"
    if [[ -f "$ROLLOUTS_PLUGIN" ]]; then
        log_success "Argo Rollouts kubectl plugin found"
    elif command_exists kubectl-argo-rollouts; then
        log_success "Argo Rollouts kubectl plugin is installed"
    else
        log_warn "Argo Rollouts kubectl plugin not found"
        log_info "Install with: ./scripts/linux/install-argo-rollouts.sh"
    fi

    # Kargo (if enabled)
    if [[ "$ENABLE_KARGO" == "true" ]]; then
        if kubectl get deployment kargo-api -n kargo &>/dev/null 2>&1; then
            log_success "Kargo is installed"
        else
            log_warn "Kargo is not installed but --enable-kargo flag is set"
            log_info "Install with: ./scripts/linux/install-kargo.sh"
            if [[ "$NON_INTERACTIVE" != "true" ]]; then
                read -rp "Continue anyway? (y/N) " cont
                [[ "$cont" == "y" || "$cont" == "Y" ]] || exit 1
            fi
        fi
    fi

    # Values file
    if [[ -f "$VALUES_FILE" ]]; then
        log_success "Values file found: $VALUES_FILE"
    else
        log_error "Values file not found: $VALUES_FILE"
        all_good=false
    fi

    if [[ "$all_good" != "true" ]]; then
        echo ""
        log_error "Prerequisites check failed. Please install missing components."
        exit 1
    fi

    echo ""
}

remove_application() {
    log_step "Uninstalling Application"

    if ! helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE_NAME"; then
        log_warn "Release '${RELEASE_NAME}' not found in namespace '${NAMESPACE}'"
        return
    fi

    log_info "Uninstalling Helm release: ${RELEASE_NAME}"
    if helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"; then
        log_success "Helm release uninstalled"
    else
        log_error "Failed to uninstall Helm release"
        exit 1
    fi

    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        read -rp "Delete namespace '${NAMESPACE}'? (y/N) " del_ns
        if [[ "$del_ns" == "y" || "$del_ns" == "Y" ]]; then
            log_info "Deleting namespace: ${NAMESPACE}"
            kubectl delete namespace "$NAMESPACE" --timeout=60s
            log_success "Namespace deleted"
        fi
    fi

    if [[ "$ENABLE_KARGO" == "true" && "$NON_INTERACTIVE" != "true" ]]; then
        read -rp "Delete Kargo environment namespaces? (y/N) " del_kargo
        if [[ "$del_kargo" == "y" || "$del_kargo" == "Y" ]]; then
            log_info "Deleting Kargo namespaces..."
            kubectl delete namespace spring-kotlin-app-dev --ignore-not-found=true --timeout=60s
            kubectl delete namespace spring-kotlin-app-staging --ignore-not-found=true --timeout=60s
            kubectl delete namespace spring-kotlin-app-prod --ignore-not-found=true --timeout=60s
            kubectl delete namespace kargo-project-spring-kotlin-app --ignore-not-found=true --timeout=60s
            log_success "Kargo namespaces deleted"
        fi
    fi

    log_success "Uninstallation complete"
}

create_namespace() {
    log_step "Creating Namespace"

    if kubectl get namespace "$NAMESPACE" &>/dev/null 2>&1; then
        log_warn "Namespace '${NAMESPACE}' already exists"
        label=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || true)
        if [[ "$label" == "enabled" ]]; then
            log_success "Istio injection is already enabled"
        else
            log_info "Enabling Istio sidecar injection..."
            kubectl label namespace "$NAMESPACE" istio-injection=enabled --overwrite
            log_success "Istio injection enabled"
        fi
    else
        log_info "Creating namespace: ${NAMESPACE}"
        kubectl create namespace "$NAMESPACE"
        log_success "Namespace created"
        log_info "Enabling Istio sidecar injection..."
        kubectl label namespace "$NAMESPACE" istio-injection=enabled
        log_success "Istio injection enabled"
    fi

    echo ""
}

create_kargo_namespaces() {
    log_step "Creating Kargo Environment Namespaces"

    local kargo_namespaces=("spring-kotlin-app-dev" "spring-kotlin-app-staging" "spring-kotlin-app-prod" "kargo-project-spring-kotlin-app")

    for ns in "${kargo_namespaces[@]}"; do
        if kubectl get namespace "$ns" &>/dev/null 2>&1; then
            log_warn "Namespace '${ns}' already exists"
        else
            log_info "Creating namespace: ${ns}"
            kubectl create namespace "$ns"
            if [[ "$ns" != *"project"* ]]; then
                kubectl label namespace "$ns" istio-injection=enabled
                log_success "Created ${ns} with Istio injection"
            else
                log_success "Created ${ns}"
            fi
        fi
    done

    echo ""
}

install_application() {
    log_step "Deploying Application with Helm"

    pushd "$(cd "$SCRIPT_DIR/../.." && pwd)/helm-charts/app-template" > /dev/null

    local helm_args=("-f" "$VALUES_FILE" "-n" "$NAMESPACE")
    if [[ "$ENABLE_KARGO" == "true" ]]; then
        helm_args+=("--set" "kargo-config.enabled=true")
    fi

    if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "$RELEASE_NAME"; then
        log_warn "Release '${RELEASE_NAME}' already exists"
        if [[ "$NON_INTERACTIVE" != "true" ]]; then
            read -rp "Upgrade existing release? (Y/n) " upgrade
            if [[ "$upgrade" == "n" || "$upgrade" == "N" ]]; then
                log_info "Skipping deployment"
                popd > /dev/null
                return
            fi
        fi

        log_info "Upgrading Helm release: ${RELEASE_NAME}"
        if helm upgrade "$RELEASE_NAME" . "${helm_args[@]}" --force-conflicts; then
            log_success "Application upgraded successfully"
        else
            popd > /dev/null
            log_error "Helm upgrade failed"
            exit 1
        fi
    else
        log_info "Installing Helm release: ${RELEASE_NAME}"
        if helm install "$RELEASE_NAME" . "${helm_args[@]}"; then
            log_success "Application deployed successfully"
        else
            popd > /dev/null
            log_error "Helm installation failed"
            exit 1
        fi
    fi

    popd > /dev/null
    echo ""
}

verify_deployment() {
    log_step "Verifying Deployment"

    log_info "Waiting for Rollout to be created..."
    sleep 3

    if kubectl get rollout "$RELEASE_NAME" -n "$NAMESPACE" &>/dev/null 2>&1; then
        log_success "Rollout created: ${RELEASE_NAME}"
    else
        log_warn "Rollout not found (this is expected for first deployment)"
    fi

    if kubectl get service "$RELEASE_NAME" -n "$NAMESPACE" &>/dev/null 2>&1; then
        log_success "Service created: ${RELEASE_NAME}"
    else
        log_warn "Service not found"
    fi

    if kubectl get virtualservice "$RELEASE_NAME" -n "$NAMESPACE" &>/dev/null 2>&1; then
        log_success "VirtualService created: ${RELEASE_NAME}"
    else
        log_warn "VirtualService not found"
    fi

    if kubectl get destinationrule "$RELEASE_NAME" -n "$NAMESPACE" &>/dev/null 2>&1; then
        log_success "DestinationRule created: ${RELEASE_NAME}"
    else
        log_warn "DestinationRule not found"
    fi

    if kubectl get peerauthentication "$RELEASE_NAME" -n "$NAMESPACE" &>/dev/null 2>&1; then
        log_success "PeerAuthentication created (mTLS enabled)"
    else
        log_warn "PeerAuthentication not found"
    fi

    log_info "Waiting for pods to be ready (timeout: 120s)..."
    if kubectl wait --for=condition=Ready pods -l "app.kubernetes.io/name=${RELEASE_NAME}" -n "$NAMESPACE" --timeout=120s 2>/dev/null; then
        log_success "Pods are ready"
        echo ""
        log_info "Pod Status:"
        kubectl get pods -l "app.kubernetes.io/name=${RELEASE_NAME}" -n "$NAMESPACE"
    else
        log_warn "Pods are not ready yet"
        log_info "Check status with: kubectl get pods -n ${NAMESPACE}"
    fi

    if [[ "$ENABLE_KARGO" == "true" ]]; then
        echo ""
        log_info "Checking Kargo stages..."
        if kubectl get stages -n kargo-project-spring-kotlin-app &>/dev/null 2>&1; then
            log_success "Kargo stages created"
            kubectl get stages -n kargo-project-spring-kotlin-app
        else
            log_warn "Kargo stages not found"
        fi
    fi

    echo ""
}

watch_rollout() {
    log_step "Watching Rollout Progress"

    log_info "Monitoring canary deployment..."
    log_info "Press Ctrl+C to stop watching (deployment will continue)"
    echo ""

    ROLLOUTS_PLUGIN="$(cd "$SCRIPT_DIR/../.." && pwd)/tools/kubectl-plugins/kubectl-argo-rollouts"
    if [[ -f "$ROLLOUTS_PLUGIN" ]]; then
        "$ROLLOUTS_PLUGIN" get rollout "$RELEASE_NAME" -n "$NAMESPACE" --watch
    elif command_exists kubectl-argo-rollouts; then
        kubectl argo rollouts get rollout "$RELEASE_NAME" -n "$NAMESPACE" --watch
    else
        log_warn "Argo Rollouts kubectl plugin not found"
        log_info "Falling back to pod watch..."
        kubectl get pods -l "app.kubernetes.io/name=${RELEASE_NAME}" -n "$NAMESPACE" --watch
    fi
}

show_access_instructions() {
    log_step "Access Instructions"
    echo ""
    log_info "Application has been deployed successfully!"
    echo ""

    ROLLOUTS_PLUGIN="$(cd "$SCRIPT_DIR/../.." && pwd)/tools/kubectl-plugins/kubectl-argo-rollouts"

    echo -e "${YELLOW}📊 Monitor Rollout Progress:${NC}"
    if [[ -f "$ROLLOUTS_PLUGIN" ]]; then
        echo -e "${CYAN}   ./tools/kubectl-plugins/kubectl-argo-rollouts get rollout ${RELEASE_NAME} -n ${NAMESPACE} --watch${NC}"
    else
        echo -e "${CYAN}   kubectl argo rollouts get rollout ${RELEASE_NAME} -n ${NAMESPACE} --watch${NC}"
    fi
    echo ""

    echo -e "${YELLOW}🌐 Access Application:${NC}"
    echo -e "${CYAN}   kubectl port-forward svc/${RELEASE_NAME} 8080:80 -n ${NAMESPACE}${NC}"
    echo -e "${GREEN}   Then open: http://localhost:8080/actuator/health${NC}"
    echo ""

    echo -e "${YELLOW}📈 Launch Argo Rollouts Dashboard:${NC}"
    if [[ -f "$ROLLOUTS_PLUGIN" ]]; then
        echo -e "${CYAN}   ./tools/kubectl-plugins/kubectl-argo-rollouts dashboard${NC}"
    else
        echo -e "${CYAN}   kubectl argo rollouts dashboard${NC}"
    fi
    echo -e "${GREEN}   Then open: http://localhost:3100${NC}"
    echo ""

    if [[ "$ENABLE_KARGO" == "true" ]]; then
        echo -e "${YELLOW}🚀 Kargo UI:${NC}"
        echo -e "${CYAN}   kubectl port-forward svc/kargo-api 8081:80 -n kargo${NC}"
        echo -e "${GREEN}   Then open: http://localhost:8081${NC}"
        echo ""
    fi

    echo -e "${YELLOW}🔍 Useful Commands:${NC}"
    echo -e "${WHITE}   # View all resources${NC}"
    echo -e "${CYAN}   kubectl get all,vs,dr,pa -n ${NAMESPACE}${NC}"
    echo ""
    echo -e "${WHITE}   # View logs${NC}"
    echo -e "${CYAN}   kubectl logs -f -l app.kubernetes.io/name=${RELEASE_NAME} -n ${NAMESPACE} -c spring-kotlin-app${NC}"
    echo ""
    echo -e "${WHITE}   # Promote canary${NC}"
    echo -e "${CYAN}   kubectl argo rollouts promote ${RELEASE_NAME} -n ${NAMESPACE}${NC}"
    echo ""
    echo -e "${WHITE}   # Rollback${NC}"
    echo -e "${CYAN}   kubectl argo rollouts abort ${RELEASE_NAME} -n ${NAMESPACE}${NC}"
    echo ""

    echo -e "${YELLOW}📚 Documentation:${NC}"
    echo -e "${CYAN}   Full guide: SPRING-KOTLIN-APP-DEPLOYMENT.md${NC}"
    echo -e "${CYAN}   Commands:   DEPLOY-COMMANDS.md${NC}"
    echo -e "${CYAN}   Checklist:  DEPLOYMENT-CHECKLIST.md${NC}"
    echo ""
}

# Main
show_banner

if [[ "$UNINSTALL" == "true" ]]; then
    remove_application
    exit 0
fi

if [[ "$SKIP_CHECKS" != "true" ]]; then
    check_prerequisites
fi

create_namespace

if [[ "$ENABLE_KARGO" == "true" ]]; then
    create_kargo_namespaces
fi

install_application
verify_deployment
show_access_instructions

if [[ "$WAIT" == "true" ]]; then
    watch_rollout
fi

log_success "Deployment script completed successfully!"
echo ""
