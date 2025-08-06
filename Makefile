# ──────────────────────────────────────────────────────────────────────────────
# Extended Makefile for:
#   1) Building & pushing a Docker image
#   2) Generating a Helm chart from docker-compose via Kompose (in Docker)
#   3) Installing/uninstalling the Helm chart
#   4) Packaging & publishing the Helm chart to a chart registry
# ──────────────────────────────────────────────────────────────────────────────

# Use bash for inline scripting and prompt logic
SHELL := /bin/bash

# ANSI codes for colors
GREEN  := \033[0;32m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
RED    := \033[0;31m
NC     := \033[0m    # No color

# Emojis
CHECK   := ✅
CROSS   := ❌
ROCKET  := 🚀
BUILDER := 🏗️ 
PACKAGE := 📦

# ──────────────────────────────────────────────────────────────────────────────
# Environment variables & defaults
# (override via `export <VAR>=value` or inline: `VAR=value make <target>`)
# ──────────────────────────────────────────────────────────────────────────────

# Docker-related
IMAGE_NAME      ?= greicodex/plantuml
IMAGE_TAG       ?= latest
IMAGE_REGISTRY  ?= docker.io
DOCKERFILE      ?= Dockerfile
COMPOSE_FILE    ?= docker-compose.yaml
KOMPOSE_IMAGE   ?= greicodex/kompose:latest

# Helm-related
NAMESPACE       ?= plantuml
RELEASE_NAME    ?= plantuml
CHART_NAME      ?= plantuml
CHART_DIR       ?= ./$(CHART_NAME)
CHART_VERSION   ?= 0.1.1
CHART_PACKAGE_DIR ?= ./chart-packages
HELM_REGISTRY   ?= oci://ghcr.io/myorg  # Example for an OCI registry
HELM_REPO       ?= my-helm-repo        # If you're pushing to a chart museum or repo with `helm push plugin`

# If you'd like to prompt the user for a value (only if not set), you could do:
# ifeq ($(NAMESPACE),)
#   NAMESPACE := $(shell read -p "🤔 Please enter Kubernetes namespace [default]: " ns; echo $${ns:-default})
# endif

.PHONY: help build push chart install uninstall package-chart publish-chart clean

## help: Show available make targets
help:
	@echo -e "$(CYAN)Available targets:$(NC)"
	@echo -e "  $(GREEN)make help$(NC)             - Show this help message"
	@echo -e "  $(GREEN)make build$(NC)            - Build Docker image"
	@echo -e "  $(GREEN)make push$(NC)             - Push Docker image to registry"
	@echo -e "  $(GREEN)make chart$(NC)            - Generate a Helm chart with Kompose"
	@echo -e "  $(GREEN)make install$(NC)          - Install/upgrade the Helm chart"
	@echo -e "  $(GREEN)make uninstall$(NC)        - Uninstall the Helm release"
	@echo -e "  $(GREEN)make package-chart$(NC)    - Package the Helm chart into a .tgz"
	@echo -e "  $(GREEN)make publish-chart$(NC)    - Push the packaged chart to a registry/repo"
	@echo -e "  $(GREEN)make clean$(NC)            - Remove generated chart files and packages"

# ──────────────────────────────────────────────────────────────────────────────
# 1) Build & push Docker container
# ──────────────────────────────────────────────────────────────────────────────

## build: Build Docker image from Dockerfile
build:
	@echo -e "$(BUILDER)  $(YELLOW)Building Docker image '$(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)'...$(NC)"
	@if [ ! -f "$(DOCKERFILE)" ]; then \
	  echo -e "$(RED)$(CROSS)  Dockerfile '$(DOCKERFILE)' not found!$(NC)"; \
	  exit 1; \
	fi
	docker build -t $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) -f $(DOCKERFILE) .
	@echo -e "$(CHECK)  $(GREEN)Build complete!$(NC)"

## push: Push Docker image to registry
push:
	@echo -e "$(ROCKET)  $(YELLOW)Pushing Docker image '$(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)'...$(NC)"
	docker push $(IMAGE_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	@echo -e "$(CHECK)  $(GREEN)Image pushed successfully!$(NC)"

# ──────────────────────────────────────────────────────────────────────────────
# 2) Generate Helm chart from Docker Compose (using Kompose in Docker)
# ──────────────────────────────────────────────────────────────────────────────

## chart: Use Kompose (in Docker) to generate a Helm chart from Docker Compose
chart:
	@echo -e "$(BUILDER)  $(YELLOW)Generating Helm chart with Kompose...$(NC)"
	@if [ ! -f "$(COMPOSE_FILE)" ]; then \
	  echo -e "$(RED)$(CROSS)  Could not find '$(COMPOSE_FILE)'! Please ensure it exists.$(NC)"; \
	  exit 1; \
	fi
	@docker run --rm -it -v $(PWD):/src $(KOMPOSE_IMAGE) \
	  convert --chart \
	  	   --provider=kubernetes \
	           --out=$(CHART_NAME) \
	           --namespace=$(NAMESPACE) \
	           --push-image \
	           --file=/src/$(COMPOSE_FILE) convert
	@sed -i 's#  annotations:#  annotations:\n    cert-manager.io/cluster-issuer: letsencrypt-prod#' $(CHART_NAME)/templates/$(CHART_NAME)-ingress.yaml
#	@sed -i 's#      secretName: \([a-z-]*\)#      secretName: \1\n      issuerRef:\n        name: letsencrypt-staging\n        kind: ClusterIssuer#i' $(CHART_NAME)/templates/$(CHART_NAME)-ingress.yaml
	@echo -e "$(CHECK)  $(GREEN)Helm chart generated: $(CHART_DIR)$(NC)"

# ──────────────────────────────────────────────────────────────────────────────
# 3) Install/Uninstall the Helm chart
# ──────────────────────────────────────────────────────────────────────────────

## install: Use Helm (locally) to install or upgrade the newly generated chart
install: chart
	@echo -e "$(ROCKET)  $(YELLOW)Installing/upgrading Helm release '$(RELEASE_NAME)' in namespace '$(NAMESPACE)'...$(NC)"
	@if [ ! -d "$(CHART_DIR)" ]; then \
	  echo -e "$(RED)$(CROSS)  Chart directory '$(CHART_DIR)' not found! Run 'make chart' first.$(NC)"; \
	  exit 1; \
	fi
	helm upgrade --install $(RELEASE_NAME) $(CHART_DIR) \
	    --namespace $(NAMESPACE) \
	    --create-namespace
	@echo -e "$(CHECK)  $(GREEN)Helm install/upgrade complete!$(NC)"

## uninstall: Uninstall the Helm release
uninstall:
	@echo -e "$(CROSS)  $(YELLOW)Uninstalling Helm release '$(RELEASE_NAME)' from namespace '$(NAMESPACE)'...$(NC)"
	helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE) || true
	@echo -e "$(CHECK)  $(GREEN)Helm release '$(RELEASE_NAME)' uninstalled!$(NC)"

# ──────────────────────────────────────────────────────────────────────────────
# 4) Package & Publish the Helm chart
# ──────────────────────────────────────────────────────────────────────────────

## package-chart: Package the Helm chart into a .tgz
package-chart: chart
	@echo -e "$(PACKAGE)  $(YELLOW)Packaging Helm chart '$(CHART_NAME)' (version $(CHART_VERSION))...$(NC)"
	@if [ ! -d "$(CHART_DIR)" ]; then \
	  echo -e "$(RED)$(CROSS)  Chart directory '$(CHART_DIR)' not found! Run 'make chart' first.$(NC)"; \
	  exit 1; \
	fi
	mkdir -p $(CHART_PACKAGE_DIR)
	helm package $(CHART_DIR) \
	  --version $(CHART_VERSION) \
	  --destination $(CHART_PACKAGE_DIR)
	@echo -e "$(CHECK)  $(GREEN)Chart packaged into $(CHART_PACKAGE_DIR)!$(NC)"

## publish-chart: Push the packaged chart to a registry or chart repo
publish-chart: package-chart
	@echo -e "$(ROCKET)  $(YELLOW)Publishing Helm chart '$(CHART_NAME)' to registry/repo...$(NC)"
	# If pushing to an OCI registry (Helm 3.8+):
	# 1) helm registry login ...
	# 2) helm push <packaged>.tgz oci://<your-registry>
	# If pushing to a ChartMuseum or similar via helm-push plugin:
	# 1) helm repo add $(HELM_REPO) ...
	# 2) helm push <packaged>.tgz $(HELM_REPO)
	#
	# Example: OCI push (requires Helm >= 3.8 and `experimental` features):
	#
	#  helm registry login $(HELM_REGISTRY) -u <USERNAME> -p <PASSWORD>
	#  helm push $(CHART_PACKAGE_DIR)/$(CHART_NAME)-$(CHART_VERSION).tgz $(HELM_REGISTRY)
	#
	# Or a chartmuseum/helm-push scenario:
	#
	#  helm push $(CHART_PACKAGE_DIR)/$(CHART_NAME)-$(CHART_VERSION).tgz $(HELM_REPO)
	#
	# For now, we'll just echo commands to be run:
	@echo -e "$(CYAN)Simulating push (customize as needed)...$(NC)"
	@echo -e "helm registry login $(HELM_REGISTRY) -u <USERNAME> -p <PASSWORD>"
	@echo -e "helm push $(CHART_PACKAGE_DIR)/$(CHART_NAME)-$(CHART_VERSION).tgz $(HELM_REGISTRY)"
	@echo -e "$(CHECK)  $(GREEN)Chart publish step complete!$(NC)"

# ──────────────────────────────────────────────────────────────────────────────
# Cleanup
# ──────────────────────────────────────────────────────────────────────────────

## clean: Remove generated chart folder and packaged .tgz files
clean:
	@echo -e "$(CROSS)  $(YELLOW)Removing generated chart folder '$(CHART_DIR)' and packaged charts in '$(CHART_PACKAGE_DIR)'...$(NC)"
	rm -rf $(CHART_DIR) $(CHART_PACKAGE_DIR)
	@echo -e "$(CHECK)  $(GREEN)Cleanup complete.$(NC)"

