
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

.PHONY: bootstrap.sh
bootstrap.sh:
	./create_bootstrap.sh

docker-build-alpine: bootstrap.sh
	docker build $(BUILD_ARGS) -t dots-alpine .
	docker tag dots-alpine dots

docker-build-debian: bootstrap.sh
	docker build $(BUILD_ARGS) --build-arg IMAGE=debian -t dots-debian .

docker-build-fedora: bootstrap.sh
	docker build $(BUILD_ARGS) --build-arg IMAGE=fedora -t dots-fedora .

docker-run-alpine:
	docker run -itv $(PWD):/app -v /var/cache -v /root/dev dots-alpine

docker-run-debian:
	docker run -itv $(PWD):/app -v /var/cache -v /root/dev dots-debian

docker-run-fedora:
	docker run -itv $(PWD):/app -v /var/cache -v /root/dev dots-fedora

docker-build-all: docker-build-alpine docker-build-fedora docker-build-debian
docker-build:
	make -j4 docker-build-all

.PHONY: default docker-build docker-build-all docker-build-alpine docker-build-fedora docker-build-debian docker-run-alpine docker-run-debian docker-run-fedora
