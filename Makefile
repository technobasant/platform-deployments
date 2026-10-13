# make cluster bootstrap demo   — a three-node kind cluster running the whole platform
include versions.env
export

.PHONY: help cluster images load bootstrap demo release-good release-bad lint policy-test \
        tf-check ci-local measure-bootstrap measure-rollout measure-canary measure-policies \
        measure-drain measure-footprint down

help: ## list targets
	@grep -hE '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-18s %s\n", $$1, $$2}'

cluster: ## create the kind cluster (1 control plane + 2 workers) and load the images
	kind get clusters | grep -qx $(CLUSTER) || kind create cluster --config kind/cluster.yaml --image $(KIND_NODE_IMAGE)
	@docker image inspect governed-agent-python:$(GA_REF) >/dev/null 2>&1 || scripts/images.sh
	scripts/load-images.sh

images: ## build governed-agent at its pinned tag, and the Git server image
	scripts/images.sh

load: ## copy the built images into the kind nodes
	scripts/load-images.sh

bootstrap: ## Argo CD, the in-cluster Git server, then the app-of-apps
	scripts/bootstrap.sh

demo: ## ask the deployed agent a question
	scripts/demo.sh

release-good: ## roll out a new revision through the canary (NOTE=...)
	scripts/release.sh $(or $(NOTE),good-$(shell date +%H%M%S))

release-bad: ## roll out a revision whose sidecar fails 30% of requests (NOTE=...)
	scripts/release.sh $(or $(NOTE),bad-$(shell date +%H%M%S)) 30

lint: ## helm lint + helm template | kubeconform -strict
	scripts/check-manifests.sh

policy-test: ## kyverno test against passing and failing manifests
	docker run --rm -v "$(CURDIR)":/work -w /work/policies/tests $(KYVERNO_CLI_IMAGE) test .

tf-check: ## terraform fmt/validate, tflint, trivy (static; nothing is applied)
	scripts/terraform-check.sh

ci-local: lint policy-test tf-check ## the static CI jobs, locally

measure-bootstrap: ## zero to all Applications healthy, RUNS times (recreates the cluster)
	scripts/measure/bootstrap.sh $(or $(RUNS),3)

measure-rollout: ## good canary under steady load, RUNS times
	scripts/measure/rollout.sh $(or $(RUNS),3)

measure-canary: ## bad canary under steady load: time to abort, requests that hit it
	scripts/measure/bad-canary.sh $(or $(RUNS),3)

measure-policies: ## one violating manifest per Kyverno policy, expect each rejected
	scripts/measure/policies.sh

measure-drain: ## drain a worker under steady load, RUNS times
	scripts/measure/drain.sh $(or $(RUNS),3)

measure-footprint: ## kubectl top, per node and per namespace
	scripts/measure/footprint.sh

down: ## delete the kind cluster
	kind delete cluster --name $(CLUSTER)
