#!/usr/bin/env bash

cat setup/env.sh > bootstrap.sh
cat setup/util.sh >> bootstrap.sh

cat setup/git.sh >> bootstrap.sh
cat setup/repos.sh >> bootstrap.sh

echo '(cd $DOTS_REPO && source setup.sh)' >> bootstrap.sh
chmod +x bootstrap.sh
