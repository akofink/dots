default:
	cat Makefile

docker-build-alpine:
	docker build -t dots-alpine .
	docker tag dots-alpine dots

docker-build-debian:
	docker build --build-arg IMAGE=debian -t dots-debian .

docker-build-fedora:
	docker build --build-arg IMAGE=fedora -t dots-fedora .

docker-build-centos-7:
	docker build --build-arg IMAGE=centos:7 -t dots-centos-7 .

docker-run-alpine:
	docker run -itv $(PWD):/app dots-alpine

docker-run-debian:
	docker run -itv $(PWD):/app dots-debian

docker-run-fedora:
	docker run -itv $(PWD):/app dots-fedora

docker-run-centos-7:
	docker run -itv $(PWD):/app -v $(PWD)/centos-7/var/cache:/var/cache -v $(PWD)/centos-7/root:/root dots-centos-7

docker-build-all: docker-build-alpine docker-build-fedora docker-build-debian docker-build-centos-7
docker-build:
	make -j4 docker-build-all

.PHONY: default docker-build docker-build-all docker-build-alpine docker-build-fedora docker-build-debian docker-build-centos-7 docker-run-alpine docker-run-debian docker-run-fedora docker-run-centos-7
