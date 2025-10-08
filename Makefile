IMAGE ?= debian

SHELLCHECK ?= shellcheck
SHELLCHECK_ARGS ?= --severity=warning
SHELLCHECK_SOURCES := $(shell find . -type f -name '*.sh' -not -path './.git/*' | sort)

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

docker-run: bootstrap.sh
	docker run -itv $(PWD):$(PWD) -w$(PWD) -v /var/cache -v /root/dev $(IMAGE) bash -c './bootstrap.sh; exec bash'

docker-run-alpine:
	IMAGE=alpine make docker-run

docker-run-debian:
	IMAGE=debian make docker-run

docker-run-fedora:
	IMAGE=fedora make docker-run

docker-build-all: docker-build-alpine docker-build-fedora docker-build-debian
docker-build:
	make -j4 docker-build-all

.PHONY: default docker-build docker-build-all docker-build-alpine docker-build-fedora docker-build-debian docker-run-alpine docker-run-debian docker-run-fedora
