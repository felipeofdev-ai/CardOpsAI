.PHONY: up down db-seed test lint stress audit cli-status all

CARDOPS_DSN ?= postgresql://cardops:cardops_secret@localhost:5432/cardops_db
export CARDOPS_DSN

up:
	docker compose up -d

down:
	docker compose down

db-seed:
	bash scripts/load_all_sql.sh

test:
	python -m pytest -q tests

lint:
	python -m compileall cardops_cli.py tests

stress:
	python cardops_cli.py stress --iterations 2000 --horizon 30

audit:
	python cardops_cli.py audit

cli-status:
	python cardops_cli.py status

all: up db-seed test cli-status
	@echo "CardOpsAI ready"
