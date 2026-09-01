.PHONY: up down db-seed test lint stress audit cli-status api serve validate all

CARDOPS_DSN ?= postgresql://cardops:cardops_secret@localhost:5432/cardops_db
export CARDOPS_DSN

up:
	docker compose up -d --build

down:
	docker compose down

db-seed:
	bash scripts/load_all_sql.sh

test:
	python -m pytest -q tests

lint:
	python -m compileall cardops_cli.py cardops_api.py api tests

stress:
	python cardops_cli.py stress --iterations 2000 --horizon 30

audit:
	python cardops_cli.py audit

cli-status:
	python cardops_cli.py status

api:
	python cardops_api.py

serve:
	powershell -ExecutionPolicy Bypass -File scripts/serve_dashboard.ps1

validate:
	python scripts/validate_system.py

all: up db-seed test cli-status
	@echo "CardOpsAI Tier-0 ready — API :8000 · Dashboard :8888 · Adminer :8080"
