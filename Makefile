IMAGE ?= debian

SHELLCHECK ?= shellcheck
SHELLCHECK_ARGS ?= --severity=warning
SHELLCHECK_SOURCES := $(shell find . -type f -name '*.sh' -not -path './.git/*' | sort)

.PHONY: default
default:
	cat Makefile

.PHONY: check
check:
	@if [ -z "$(SHELLCHECK_SOURCES)" ]; then \
		echo "No shell scripts found to lint."; \
	else \
		$(SHELLCHECK) $(SHELLCHECK_ARGS) $(SHELLCHECK_SOURCES); \
	fi

bootstrap.sh: **/*.sh
	./create_bootstrap.sh

.PHONY: docker-run
docker-run: bootstrap.sh
	docker run -itv $(PWD):$(PWD) -w$(PWD) \
		-v /var/cache -v /var/lib/apt/lists -v /root/dev \
		$(IMAGE) \
		bash -c \
		'./bootstrap.sh; exec bash'

.PHONY: docker-run-alpine
docker-run-alpine:
	IMAGE=alpine make docker-run

.PHONY: docker-run-debian
docker-run-debian:
	IMAGE=debian make docker-run

.PHONY: docker-run-fedora
docker-run-fedora:
	IMAGE=fedora make docker-run
