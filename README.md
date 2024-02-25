dots
====

My dot and config files and scripts to install them.

### Set up a new machine (OS X, Linux):

```
curl -O https://raw.githubusercontent.com/akofink/dots/main/bootstrap.sh && source bootstrap.sh
```

### Contributing

Fork this repo, and add your own templates. Pull requests for updates to setup scripts are welcome!

#### Local development and Testing

A Makefile is provided with some commands for testing across various Linux distros:

```
make docker-build # build all three Linux variants

# Run the top level setup.sh in a new container, and drop the user into a shell afterwards:
make docker-run-alpine
make docker-run-debian
make docker-run-fedora
make docker-run-centos-7
```

