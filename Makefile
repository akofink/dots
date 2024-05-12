default:
	cat Makefile

docker-build-alpine:
	docker build -t dots-alpine .
	docker tag dots-alpine dots

docker-build-debian:
	docker build --build-arg IMAGE=debian -t dots-debian .

docker-build-fedora:
	docker build --build-arg IMAGE=fedora -t dots-fedora .

docker-run-alpine:
	docker run -itv $(PWD):/app -v /root/dev dots-alpine

docker-run-debian:
	docker run -itv $(PWD):/app -v /var/cache -v /root/dev dots-debian

docker-run-fedora:
	docker run -itv $(PWD):/app -v /var/cache -v /root/dev dots-fedora

docker-build-all: docker-build-alpine docker-build-fedora docker-build-debian
docker-build:
	make -j4 docker-build-all

.PHONY: default docker-build docker-build-all docker-build-alpine docker-build-fedora docker-build-debian docker-run-alpine docker-run-debian docker-run-fedora
