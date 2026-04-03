#!/bin/bash
# Build script for My Local Kubernetes Cluster
# Bash alternative to build.ps1 and Makefile

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TARGET="${1:-help}"

show_help() {
    cat << EOF
$(echo -e "\033[1;36m")My Local Kubernetes Cluster - Available targets:$(echo -e "\033[0m")

  ./build.sh install          - Install all components interactively
  ./build.sh install-quiet    - Install all components non-interactively
  ./build.sh verify           - Verify cluster status and installed components
  ./build.sh uninstall        - Remove all installed components (keeps cluster)
  ./build.sh clean            - Remove tools and credentials directories
  ./build.sh create-cluster   - Create the kind cluster
  ./build.sh delete-cluster   - Delete the kind cluster
  ./build.sh status           - Show cluster and component status

Component-specific installs:
  ./build.sh install-cert-manager
  ./build.sh install-istio
  ./build.sh install-argocd
  ./build.sh install-rollouts
  ./build.sh install-kargo
  ./build.sh install-dashboard

Access UIs:
  ./build.sh dashboard        - Start kubectl proxy for dashboard access
  ./build.sh argocd-ui        - Port-forward ArgoCD UI to https://localhost:8080
  ./build.sh kargo-ui         - Port-forward Kargo UI to http://localhost:8081
  ./build.sh rollouts-ui      - Launch Argo Rollouts dashboard
  ./build.sh expose-gateway   - Expose Istio gateway for path-based routing

Infrastructure:
  ./build.sh setup-infrastructure - Setup SSL certificates and Istio routing

Helm Chart Verification:
  ./build.sh helm-lint        - Lint Helm charts for errors
  ./build.sh helm-template    - Test chart template rendering
  ./build.sh helm-test        - Run Helm tests (requires deployment)
  ./build.sh helm-package     - Package Helm charts
  ./build.sh helm-verify      - Run all Helm verifications (lint + template)
  ./build.sh helm-build       - Build charts (update deps + verify + package)

Workflows:
  ./build.sh setup            - Complete setup (create + install + verify)
  ./build.sh teardown         - Complete teardown (uninstall + delete + clean)

EOF
}

case "$TARGET" in
    help)
        show_help
        ;;
    
    install)
        bash "$SCRIPT_DIR/scripts/linux/install-all.sh"
        ;;
    
    install-quiet)
        bash "$SCRIPT_DIR/scripts/linux/install-all.sh" --non-interactive
        ;;
    
    install-cert-manager)
        bash "$SCRIPT_DIR/scripts/linux/install-cert-manager.sh"
        ;;
    
    install-istio)
        bash "$SCRIPT_DIR/scripts/linux/install-istio.sh"
        ;;
    
    install-argocd)
        bash "$SCRIPT_DIR/scripts/linux/install-argocd.sh"
        ;;
    
    install-rollouts)
        bash "$SCRIPT_DIR/scripts/linux/install-argo-rollouts.sh"
        ;;
    
    install-kargo)
        bash "$SCRIPT_DIR/scripts/linux/install-kargo.sh"
        ;;
    
    setup-infrastructure)
        bash "$SCRIPT_DIR/scripts/linux/setup-infrastructure.sh"
        ;;
    
    install-dashboard)
        bash "$SCRIPT_DIR/scripts/linux/install-dashboard.sh"
        ;;
    
    verify|status)
        bash "$SCRIPT_DIR/scripts/linux/verify-cluster.sh"
        ;;
    
    create-cluster)
        echo -e "\033[1;36mCreating kind cluster: my-local-cluster\033[0m"
        kind create cluster --name my-local-cluster
        ;;
    
    delete-cluster)
        echo -e "\033[1;33mDeleting kind cluster: my-local-cluster\033[0m"
        kind delete cluster --name my-local-cluster
        ;;
    
    uninstall)
        bash "$SCRIPT_DIR/scripts/linux/uninstall-all.sh"
        ;;
    
    clean)
        echo -e "\033[1;33mCleaning up tools and credentials directories...\033[0m"
        if [[ -d "$SCRIPT_DIR/tools" ]]; then
            rm -rf "$SCRIPT_DIR/tools"
            echo -e "  \033[1;32m✓ Removed tools/\033[0m"
        fi
        if [[ -d "$SCRIPT_DIR/credentials" ]]; then
            rm -rf "$SCRIPT_DIR/credentials"
            echo -e "  \033[1;32m✓ Removed credentials/\033[0m"
        fi
        echo -e "\033[1;32mCleanup complete!\033[0m"
        ;;
    
    dashboard)
        echo -e "\033[1;36mStarting kubectl proxy for dashboard access...\033[0m"
        echo -e "\033[1;37mAccess dashboard at: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/\033[0m"
        echo -e "\033[1;33mToken location: ./credentials/service-accounts/admin-user-kubernetes-dashboard.txt\033[0m"
        kubectl proxy
        ;;
    
    argocd-ui)
        echo -e "\033[1;36mPort-forwarding ArgoCD UI to https://localhost:8080\033[0m"
        echo -e "\033[1;33mCredentials location: ./credentials/argocd-credentials.txt\033[0m"
        kubectl port-forward svc/argocd-server -n argocd 8080:443
        ;;
    
    kargo-ui)
        echo -e "\033[1;36mPort-forwarding Kargo UI to http://localhost:8081\033[0m"
        kubectl port-forward svc/kargo-api -n kargo 8081:443
        ;;
    
    rollouts-ui)
        echo -e "\033[1;36mLaunching Argo Rollouts dashboard...\033[0m"
        ROLLOUTS="$SCRIPT_DIR/tools/kubectl-plugins/kubectl-argo-rollouts"
        if [[ -f "$ROLLOUTS" ]]; then
            "$ROLLOUTS" dashboard
        else
            echo -e "\033[1;31mERROR: kubectl-argo-rollouts plugin not found.\033[0m"
            echo -e "\033[1;33mRun './build.sh install-rollouts' first.\033[0m"
            exit 1
        fi
        ;;
    
    expose-gateway)
        echo -e "\033[1;36mExposing Istio Ingress Gateway...\033[0m"
        echo -e "\033[1;33mAccess URLs:\033[0m"
        echo -e "\033[1;37m  ArgoCD:             https://localhost:8443/argocd\033[0m"
        echo -e "\033[1;37m  Kargo:              https://localhost:8443/kargo\033[0m"
        echo -e "\033[1;37m  Dashboard:          https://localhost:8443/dashboard\033[0m"
        echo -e "\033[1;37m  Argo Rollouts:      https://localhost:8443/rollouts\033[0m"
        echo -e "\n\033[1;33mPress Ctrl+C to stop port-forwarding\033[0m"
        kubectl port-forward -n istio-system svc/istio-ingressgateway 8443:443 8080:80
        ;;
    
    setup)
        echo -e "\n\033[1;36m=== Complete Setup Workflow ===\033[0m"
        echo -e "\033[1;33m1. Creating cluster...\033[0m"
        kind create cluster --name my-local-cluster
        
        echo -e "\n\033[1;33m2. Installing components...\033[0m"
        bash "$SCRIPT_DIR/scripts/linux/install-all.sh" --non-interactive
        
        echo -e "\n\033[1;33m3. Verifying installation...\033[0m"
        bash "$SCRIPT_DIR/scripts/linux/verify-cluster.sh"
        
        echo -e "\n\033[1;32m=== Setup Complete! ===\033[0m"
        echo -e "\033[1;32mYour local Kubernetes cluster is ready.\033[0m"
        ;;
    
    teardown)
        echo -e "\n\033[1;33m=== Complete Teardown Workflow ===\033[0m"
        
        read -p "This will remove the cluster and all data. Continue? (yes/no) " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo -e "\033[1;36mTeardown cancelled.\033[0m"
            exit 0
        fi
        
        echo -e "\n\033[1;33m1. Uninstalling components...\033[0m"
        bash "$SCRIPT_DIR/scripts/linux/uninstall-all.sh" --force
        
        echo -e "\n\033[1;33m2. Deleting cluster...\033[0m"
        kind delete cluster --name my-local-cluster
        
        echo -e "\n\033[1;33m3. Cleaning directories...\033[0m"
        [[ -d "$SCRIPT_DIR/tools" ]] && rm -rf "$SCRIPT_DIR/tools"
        [[ -d "$SCRIPT_DIR/credentials" ]] && rm -rf "$SCRIPT_DIR/credentials"
        
        echo -e "\n\033[1;32m=== Teardown Complete! ===\033[0m"
        ;;
    
    helm-lint)
        echo -e "\n\033[1;36m=== Linting Helm Charts ===\033[0m"
        CHART_PATH="$SCRIPT_DIR/helm-charts/app-template"
        
        if [[ ! -d "$CHART_PATH" ]]; then
            echo -e "\033[1;31mERROR: Chart not found at $CHART_PATH\033[0m"
            exit 1
        fi
        
        echo -e "\033[1;33mLinting chart: app-template\033[0m"
        helm lint "$CHART_PATH"
        
        if [[ $? -eq 0 ]]; then
            echo -e "\n\033[1;32m✓ Helm lint passed!\033[0m"
        else
            echo -e "\n\033[1;31m✗ Helm lint failed!\033[0m"
            exit 1
        fi
        ;;
    
    helm-template)
        echo -e "\n\033[1;36m=== Testing Chart Template Rendering ===\033[0m"
        CHART_PATH="$SCRIPT_DIR/helm-charts/app-template"
        
        echo -e "\033[1;33mTesting basic rendering...\033[0m"
        if helm template test-app "$CHART_PATH" --debug &> /dev/null; then
            echo -e "\033[1;32m✓ Basic rendering passed\033[0m"
        else
            echo -e "\033[1;31m✗ Basic template rendering failed!\033[0m"
            exit 1
        fi
        
        echo -e "\n\033[1;33mTesting with Istio routing...\033[0m"
        if helm template test-app "$CHART_PATH" --set istio-routing.ingress.path=/test --debug &> /dev/null; then
            echo -e "\033[1;32m✓ Istio routing passed\033[0m"
        else
            echo -e "\033[1;31m✗ Istio routing template failed!\033[0m"
            exit 1
        fi
        
        echo -e "\n\033[1;33mTesting with canary enabled...\033[0m"
        if helm template test-app "$CHART_PATH" --set istio-routing.trafficRouting.enabled=true --debug &> /dev/null; then
            echo -e "\033[1;32m✓ Canary routing passed\033[0m"
        else
            echo -e "\033[1;31m✗ Canary template failed!\033[0m"
            exit 1
        fi
        
        echo -e "\n\033[1;33mTesting with Kargo enabled...\033[0m"
        if helm template test-app "$CHART_PATH" --set kargo-config.enabled=true --debug &> /dev/null; then
            echo -e "\033[1;32m✓ Kargo config passed\033[0m"
        else
            echo -e "\033[1;31m✗ Kargo template failed!\033[0m"
            exit 1
        fi
        
        echo -e "\n\033[1;32m✓ All template tests passed!\033[0m"
        ;;
    
    helm-test)
        echo -e "\n\033[1;36m=== Running Helm Tests ===\033[0m"
        
        RELEASES=$(helm list -o json)
        if [[ "$RELEASES" == "[]" ]] || [[ -z "$RELEASES" ]]; then
            echo -e "\033[1;33mNo Helm releases found. Deploy a chart first:\033[0m"
            echo -e "\033[1;37m  helm install myapp ./helm-charts/app-template --wait\033[0m"
            exit 1
        fi
        
        echo -e "\033[1;33mAvailable releases:\033[0m"
        echo "$RELEASES" | jq -r '.[] | "  - \(.name) (namespace: \(.namespace))"'
        
        read -p $'\nEnter release name to test: ' RELEASE_NAME
        
        if [[ -n "$RELEASE_NAME" ]]; then
            echo -e "\n\033[1;36mRunning tests for release: $RELEASE_NAME\033[0m"
            helm test "$RELEASE_NAME" --logs
            
            if [[ $? -eq 0 ]]; then
                echo -e "\n\033[1;32m✓ All tests passed!\033[0m"
            else
                echo -e "\n\033[1;31m✗ Some tests failed. Check logs above.\033[0m"
                exit 1
            fi
        else
            echo -e "\033[1;33mNo release name provided.\033[0m"
        fi
        ;;
    
    helm-package)
        echo -e "\n\033[1;36m=== Packaging Helm Charts ===\033[0m"
        CHART_PATH="$SCRIPT_DIR/helm-charts/app-template"
        OUTPUT_DIR="$SCRIPT_DIR/helm-charts/packages"
        
        # Create output directory
        mkdir -p "$OUTPUT_DIR"
        
        echo -e "\033[1;33mUpdating dependencies...\033[0m"
        pushd "$CHART_PATH" > /dev/null
        helm dependency update
        popd > /dev/null
        
        echo -e "\n\033[1;33mPackaging chart...\033[0m"
        helm package "$CHART_PATH" --destination "$OUTPUT_DIR"
        
        if [[ $? -eq 0 ]]; then
            echo -e "\n\033[1;32m✓ Chart packaged successfully!\033[0m"
            echo -e "\033[1;36mPackage location: $OUTPUT_DIR\033[0m"
            find "$OUTPUT_DIR" -name "*.tgz" -exec basename {} \; | while read pkg; do
                echo -e "  - $pkg"
            done
        else
            echo -e "\n\033[1;31m✗ Packaging failed!\033[0m"
            exit 1
        fi
        ;;
    
    helm-verify)
        echo -e "\n\033[1;36m=== Running All Helm Verifications ===\033[0m"
        
        # Run lint
        echo -e "\n\033[1;33m[1/2] Running helm lint...\033[0m"
        bash "$0" helm-lint || exit 1
        
        # Run template tests
        echo -e "\n\033[1;33m[2/2] Running template tests...\033[0m"
        bash "$0" helm-template || exit 1
        
        echo -e "\n\033[1;32m═══════════════════════════════════════\033[0m"
        echo -e "\033[1;32m✓ All Helm verifications passed!\033[0m"
        echo -e "\033[1;32m═══════════════════════════════════════\033[0m"
        ;;
    
    helm-build)
        echo -e "\n\033[1;36m=== Building Helm Charts ===\033[0m"
        
        # Update dependencies
        echo -e "\n\033[1;33m[1/4] Updating dependencies...\033[0m"
        CHART_PATH="$SCRIPT_DIR/helm-charts/app-template"
        pushd "$CHART_PATH" > /dev/null
        helm dependency update
        popd > /dev/null
        if [[ $? -ne 0 ]]; then
            echo -e "\033[1;31m✗ Dependency update failed!\033[0m"
            exit 1
        fi
        echo -e "\033[1;32m✓ Dependencies updated\033[0m"
        
        # Run lint
        echo -e "\n\033[1;33m[2/4] Linting charts...\033[0m"
        bash "$0" helm-lint || exit 1
        
        # Run template tests
        echo -e "\n\033[1;33m[3/4] Testing templates...\033[0m"
        bash "$0" helm-template || exit 1
        
        # Package charts
        echo -e "\n\033[1;33m[4/4] Packaging charts...\033[0m"
        bash "$0" helm-package || exit 1
        
        echo -e "\n\033[1;32m═══════════════════════════════════════\033[0m"
        echo -e "\033[1;32m✓ Helm chart build complete!\033[0m"
        echo -e "\033[1;32m═══════════════════════════════════════\033[0m"
        ;;
    
    *)
        echo -e "\033[1;31mUnknown target: $TARGET\033[0m"
        show_help
        exit 1
        ;;
esac
