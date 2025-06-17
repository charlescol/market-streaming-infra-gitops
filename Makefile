ENV ?=

.PHONY: check_env bootstrap_apply _create_repository_secret

ifdef ENV
CONFIG_DIR      := ./$(ENV)/.config
CONFIG_TEMPLATE := $(CONFIG_DIR)/config.template
CONFIG_JSON     := $(CONFIG_DIR)/config.json
KEY_FILE        := $(CONFIG_DIR)/gcp-key.json

ifeq ($(wildcard $(KEY_FILE)), $(KEY_FILE))
include $(CONFIG_DIR)/.env
export
endif
endif

bootstrap: check_env bootstrap_apply ## Bootstrap Flux and apply configuration to the environment

help: ## Display this help
	@echo "Usage: make <target> [PROJECT_ID=...] [REGION=...] [VARS_FILE=...]"
	@echo ""
	@echo "Targets :"
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) \
		| grep -v '^_' \
		| awk 'BEGIN {FS = ":.*?##"}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

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
	@$(MAKE) _create_repository_secret
	@sleep 20

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

check_env: ## Check if all required environment variables and files are set
	@if [ -z "$(ENV)" ]; then \
		echo "❌ ENV is not set"; \
		exit 1; \
	fi
	@if [ ! -d "./$(ENV)" ]; then \
		echo "❌ Environment directory './$(ENV)' does not exist"; \
		exit 1; \
	fi
	@if [ ! -f "$(CONFIG_DIR)/gcp-key.json" ]; then \
		echo "❌ Missing GCP key file: $(CONFIG_DIR)/gcp-key.json"; \
		exit 1; \
	fi
	@if [ ! -f "$(CONFIG_TEMPLATE)" ]; then \
		echo "❌ Missing config.template: $(CONFIG_TEMPLATE)"; \
		exit 1; \
	fi
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo "❌ GITHUB_TOKEN is not set"; \
		exit 1; \
	fi

	@echo "✅ All required environment variables and files are set."

_create_repository_secret: $(CONFIG_JSON)
	@for ns in flux-system backend; do \
	  echo "🔐 Creating image pull secret in namespace: $$ns"; \
	  kubectl delete secret flux-gcp-key -n $$ns --ignore-not-found; \
	  kubectl create secret generic flux-gcp-key \
	    --namespace=$$ns \
	    --from-file=.dockerconfigjson=$< \
	    --type=kubernetes.io/dockerconfigjson; \
	done
	@rm -f $<

$(CONFIG_JSON): $(CONFIG_TEMPLATE) $(KEY_FILE)
	@set -eu ;\
	mkdir -p "$(CONFIG_DIR)" ;\
	RAW_PASS=$$(tr -d '\n' < "$(KEY_FILE)") ;\
	PASSWORD_ESC=$$(printf '%s' "$$RAW_PASS" | sed 's/"/\\"/g') ;\
	AUTH=$$(printf '_json_key:%s' "$$RAW_PASS" | base64 | tr -d '\n') ;\
	IMAGE_REPO_NAME="$(IMAGE_REPO_NAME)" \
	PASSWORD_ESC="$$PASSWORD_ESC" \
	AUTH="$$AUTH" \
	envsubst '$$IMAGE_REPO_NAME $$PASSWORD_ESC $$AUTH' < "$(CONFIG_TEMPLATE)" > "$(CONFIG_JSON)"