SHELL := /bin/bash

.PHONY: setup-kind build-images deploy-tenants observability kafka-up kafka-down load-test up

setup-kind:
	./scripts/setup-kind.sh

build-images:
	./scripts/build-images.sh

deploy-tenants:
	./scripts/deploy-tenants.sh

observability:
	./scripts/install-observability.sh

kafka-up:
	./scripts/start-kafka.sh

kafka-down:
	./scripts/stop-kafka.sh

load-test:
	./scripts/run-load-test.sh user1.127.0.0.1.sslip.io

up:
	./scripts/bootstrap-all.sh
