#!/usr/bin/env bash

set -e

PREFIX="🍰  "
echo "$PREFIX Running $(basename $0)"

git config --global --add safe.directory /workspace >.tmp/postCreateCommand.log 2>&1 
echo "$PREFIX Setting up safe git repository to prevent dubious ownership errors"

echo "$PREFIX Setting up git configuration to support .gitconfig in repo-root"
git config --local --get include.path | grep -e ../.gitconfig >/dev/null >>.tmp/postCreateCommand.log 2>&1 || git config --local --add include.path ../.gitconfig >>.tmp/postCreateCommand.log 2>&1

. .devcontainer/gh-takt.sh
. .devcontainer/gpg-auth.sh

echo "$PREFIX ✅ postCreateCommand setup complete"
exit 0