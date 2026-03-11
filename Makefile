SHELL := /bin/bash

TOFU ?= tofu
KUBECTL ?= kubectl
K3D_CLUSTER_NAME ?= infra-takehome
KUBE_CONTEXT ?= k3d-$(K3D_CLUSTER_NAME)

.PHONY: up argocd app smoke-test down clean

up:
	cd tofu && $(TOFU) init
	cd tofu && $(TOFU) apply -auto-approve

argocd:
	$(KUBECTL) --context $(KUBE_CONTEXT) create namespace argocd --dry-run=client -o yaml | $(KUBECTL) --context $(KUBE_CONTEXT) apply -f -
	$(KUBECTL) --context $(KUBE_CONTEXT) apply --server-side -k argocd/argocd

app:
	$(KUBECTL) --context $(KUBE_CONTEXT) apply -f argocd/applications/postgrest.yaml

smoke-test:
	curl --fail --silent http://localhost:8080/todos

down:
	cd tofu && $(TOFU) destroy -auto-approve

clean: down
	docker rm -f postgres-infra-takehome >/dev/null 2>&1 || true
	docker volume rm postgres-infra-takehome-data >/dev/null 2>&1 || true
