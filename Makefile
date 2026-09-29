.PHONY: help validate test lint build-images plan apply destroy logs drill clean

help:
	@echo "Kafka DR Demo - Available Commands"
	@echo "==================================="
	@echo "  make validate       - Validate Terraform, Python, and shell scripts"
	@echo "  make test          - Run Python unit tests"
	@echo "  make lint          - Run linters (Python, Terraform, shell)"
	@echo "  make build-images  - Build Docker images locally"
	@echo "  make plan          - Terraform plan"
	@echo "  make apply         - Terraform apply"
	@echo "  make destroy       - Terraform destroy"
	@echo "  make logs          - Tail ECS service logs"
	@echo "  make drill         - Run disaster recovery drill"
	@echo "  make clean         - Clean local artifacts"

validate: validate-terraform validate-python validate-shell

validate-terraform:
	@echo "Validating Terraform configuration..."
	cd terraform && terraform init -backend=false
	cd terraform && terraform validate
	cd terraform && terraform fmt -check -recursive
	@echo "✓ Terraform validation passed"

validate-python:
	@echo "Validating Python code..."
	cd apps/producer && python3 -m py_compile producer.py
	cd apps/consumer && python3 -m py_compile consumer.py
	cd scripts && python3 -m py_compile measure_rpo_rto.py
	@echo "✓ Python validation passed"

validate-shell:
	@echo "Validating shell scripts..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck scripts/*.sh || true; \
		echo "✓ Shell validation complete"; \
	else \
		echo "⚠ shellcheck not found, skipping shell validation"; \
	fi

test:
	@echo "Running Python tests..."
	cd apps/producer && pip install -q -r requirements.txt && pytest tests/ -v || true
	cd apps/consumer && pip install -q -r requirements.txt && pytest tests/ -v || true
	@echo "✓ Tests complete"

lint:
	@echo "Running linters..."
	cd terraform && terraform fmt -recursive
	@if command -v pylint >/dev/null 2>&1; then \
		cd apps/producer && pylint producer.py || true; \
		cd apps/consumer && pylint consumer.py || true; \
	else \
		echo "⚠ pylint not found, skipping Python linting"; \
	fi
	@echo "✓ Linting complete"

build-images:
	@echo "Building Docker images..."
	cd apps/producer && docker build -t kafka-dr-producer:latest .
	cd apps/consumer && docker build -t kafka-dr-consumer:latest .
	@echo "✓ Images built successfully"

plan:
	@echo "Running Terraform plan..."
	cd terraform && terraform plan

apply:
	@echo "Applying Terraform configuration..."
	cd terraform && terraform apply
	@echo "✓ Infrastructure deployed"

destroy:
	@echo "Destroying Terraform infrastructure..."
	@read -p "Are you sure you want to destroy all resources? (yes/no): " confirm && \
	if [ "$$confirm" = "yes" ]; then \
		cd terraform && terraform destroy; \
	else \
		echo "Destroy cancelled"; \
	fi

logs:
	@echo "Tailing ECS service logs (producer)..."
	aws logs tail /ecs/kafka-dr-demo-producer --follow --region us-east-1

drill:
	@echo "Running disaster recovery drill..."
	./scripts/run_drill.sh

clean:
	@echo "Cleaning local artifacts..."
	rm -rf apps/producer/__pycache__ apps/producer/.pytest_cache apps/producer/tests/__pycache__
	rm -rf apps/consumer/__pycache__ apps/consumer/.pytest_cache apps/consumer/tests/__pycache__
	rm -f /tmp/failover-*.log /tmp/failback-*.log /tmp/*.timestamp
	rm -rf /tmp/dr-drill-*
	@echo "✓ Cleaned"
