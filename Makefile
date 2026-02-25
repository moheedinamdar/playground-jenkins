# ============================================================================
# Jenkins Playground — Makefile
# ============================================================================
.PHONY: help up down restart logs status clean keys jnlp-secret build

SHELL := /bin/bash

# Export the SSH public key so docker-compose can inject it into SSH agents
export JENKINS_AGENT_SSH_PUBKEY = $(shell cat secrets/jenkins_agent_key.pub 2>/dev/null || echo "")

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

keys: ## Generate SSH keypair (if not already present)
	@bash generate-ssh-key.sh

build: keys ## Build all Docker images
	docker compose build

up: keys ## Start the entire Jenkins playground (fully automated)
	@echo "▸ Starting Jenkins playground..."
	docker compose up --build -d
	@echo ""
	@echo "▸ Waiting for Jenkins master to be ready..."
	@until curl -sf http://localhost:8080/login > /dev/null 2>&1; do \
		sleep 5; \
		echo "  Still waiting..."; \
	done
	@echo "✔ Jenkins master is up!"
	@echo ""
	@echo "▸ Waiting for JCasC to finish applying (30s)..."
	@sleep 30
	@echo "▸ Fetching JNLP agent secret..."
	@JNLP_SECRET=$$(curl -sf -u admin:admin http://localhost:8080/computer/jnlp-agent-1/slave-agent.jnlp | sed -n 's/.*<argument>\([a-f0-9]\{64\}\)<\/argument>.*/\1/p'); \
	if [ -z "$$JNLP_SECRET" ]; then \
		echo "⚠ Could not fetch JNLP secret. Try 'make jnlp-secret' manually later."; \
	else \
		echo "JNLP_SECRET=$$JNLP_SECRET" > .env; \
		echo "✔ JNLP secret saved to .env"; \
		echo "▸ Restarting JNLP agent with secret..."; \
		docker compose up -d jnlp-agent-1; \
		echo "▸ Waiting 10s for JNLP agent to connect..."; \
		sleep 10; \
	fi
	@echo ""
	@echo "✔ Jenkins playground is ready!"
	@echo "  Master UI:  http://localhost:8080"
	@echo "  Login:      admin / admin"
	@echo ""
	@echo "▸ Agent status:"
	@curl -sf -u admin:admin http://localhost:8080/computer/api/json | \
		python3 -c "import sys,json; [print(f'  {c[\"displayName\"]}: {\"ONLINE\" if not c[\"offline\"] else \"OFFLINE\"}') for c in json.load(sys.stdin).get('computer',[])]" \
		2>/dev/null || echo "  (could not query — Jenkins may still be loading)"

down: ## Stop all containers
	docker compose down

restart: down up ## Restart the playground

logs: ## Tail logs from all containers
	docker compose logs -f

logs-master: ## Tail logs from master only
	docker compose logs -f jenkins-master

status: ## Show container status
	docker compose ps

jnlp-secret: ## Fetch JNLP secret and restart the JNLP agent
	@echo "▸ Fetching JNLP agent secret from master..."
	@bash fetch-jnlp-secret.sh jnlp-agent-1
	@echo ""
	@echo "▸ Copy the secret above and add it to a .env file:"
	@echo "  echo 'JNLP_SECRET=<secret>' > .env"
	@echo "  Then run: make restart-jnlp"

restart-jnlp: ## Restart the JNLP agent (after setting JNLP_SECRET in .env)
	docker compose up -d jnlp-agent-1

clean: ## Remove all containers, volumes, and secrets
	docker compose down -v --remove-orphans
	rm -rf secrets/
	rm -f .env
	@echo "✔ Cleaned up everything."

shell-master: ## Open a shell on the master
	docker exec -it jenkins-master bash

shell-ssh1: ## Open a shell on ssh-agent-1
	docker exec -it ssh-agent-1 bash

shell-ssh2: ## Open a shell on ssh-agent-2
	docker exec -it ssh-agent-2 bash

shell-jnlp: ## Open a shell on jnlp-agent-1
	docker exec -it jnlp-agent-1 bash
