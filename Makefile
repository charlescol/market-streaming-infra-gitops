ENV ?=

.PHONY: check_env bootstrap_apply setup-flink-webhook

bootstrap: check_env setup-flink-webhook bootstrap_apply ## Bootstrap Flux and apply configuration to the environment

help: ## Display this help
	@echo "Usage: make <target> [ENV=...]"
	@echo ""
	@echo "Targets :"
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?##"}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

check_env: ## Check if ENV is set
	if [ -z "$(ENV)" ]; then \
		echo "ENV is not set"; \
		exit 1; \
	fi
	if [ ! -d "./$(ENV)" ]; then \
		echo "ENV $(ENV) does not exist"; \
		exit 1; \
	fi

bootstrap_apply: ## Bootstrap Flux and apply configuration to the environment
	@echo "⚠️  You are about to apply configuration to environment: '$(ENV)'"
	@read -p "❓ Are you sure you want to continue? (yes/no): " confirm; \
	if [ "$$confirm" != "yes" ]; then \
		echo "❌ Operation cancelled."; \
		exit 1; \
	fi
	@echo "✅ Proceeding with Flux bootstrap for '$(ENV)'..."
	flux bootstrap github \
		--owner=charlescol \
		--repository=market-streaming-infra-gitops \
		--branch=main \
		--path=$(ENV) \
		--personal

	@echo "🩹 Checking if gotk-sync.yaml needs to be reapplied..."
	@if ! kubectl get gitrepository flux-system -n flux-system >/dev/null 2>&1; then \
		kubectl apply -f local/flux-system/gotk-sync.yaml; \
	fi

	@echo "🔄 Reconciling Kustomizations..."
	flux reconcile kustomization flux-system --with-source
	flux reconcile kustomization helm --with-source
	flux reconcile kustomization apps --with-source
	flux reconcile kustomization common --with-source

setup-flink-webhook: ## Setup Flink webhook
	openssl req -x509 -nodes -newkey rsa:2048 \
		-keyout tls.key -out tls.crt -days 365 \
		-subj "/CN=flink-operator.backend.svc"

	openssl pkcs12 -export \
		-in tls.crt -inkey tls.key \
		-out keystore.p12 \
		-name flink-operator \
		-passout pass:changeit
	
	kubectl -n backend create secret generic flink-operator-cert \
		--from-file=keystore.p12=keystore.p12
	
	kubectl -n backend create secret generic operator-certificate-password \
  		--from-literal=password=changeit
	
	rm tls.key tls.crt keystore.p12