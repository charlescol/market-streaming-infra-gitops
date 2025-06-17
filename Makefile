ENV ?=

.PHONY: check_env bootstrap_apply

ifeq ($(wildcard ./$(ENV)/.config/.env), ./$(ENV)/.config/.env)
include ./$(ENV)/.config/.env
export
endif

bootstrap: check_env bootstrap_apply ## Bootstrap Flux and apply configuration to the environment

help: ## Display this help
	@echo "Usage: make <target> [ENV=...]"
	@echo ""
	@echo "Targets :"
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?##"}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

check_env: ## Check if ENV is set
	@if [ -z "$(ENV)" ]; then \
		echo "ENV is not set"; \
		exit 1; \
	fi
	@if [ ! -d "./$(ENV)" ]; then \
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
	@echo "📁 Ensuring 'flux-system' namespace exists..."
	@kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply -f -

	@echo "✅ Proceeding with Flux install for '$(ENV)'..."
	flux install --namespace=flux-system  \
	  --components=source-controller,kustomize-controller,notification-controller,image-reflector-controller,image-automation-controller
	kubectl delete secret flux-system -n flux-system --ignore-not-found
	kubectl create secret generic flux-system \
	--namespace=flux-system \
	--from-literal=username=git \
	--from-literal=password=$(GITHUB_TOKEN)
	@sleep 30

	@{ \
		set -e; \
		kubectl delete secret flux-gcp-key -n flux-system --ignore-not-found && \
		kubectl create secret generic flux-gcp-key -n flux-system \
			--from-file=key.json=./$(ENV)/.config/gcp-key.json ; \
	}

	@echo "📄 Applying gotk-sync.yaml..."
	kubectl apply -f $(ENV)/flux-system/gotk-sync.yaml
	@sleep 30

	@echo "🔄 Reconciling Kustomizations..."
	@{ \
		set -e; \
		flux reconcile kustomization flux-system --with-source && \
		flux reconcile kustomization common --with-source && \
		flux reconcile kustomization helm --with-source && \
		flux reconcile kustomization apps --with-source ; \
	}
