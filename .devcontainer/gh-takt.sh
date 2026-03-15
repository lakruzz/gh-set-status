#!/usr/bin/env bash

GH_PREFIX="🐙    "
echo "$GH_PREFIX Sourcing $(basename "${BASH_SOURCE[0]}")"

set +e
gh auth status >/dev/null 2>&1
AUTH_OK=$?
set -e
if [ $AUTH_OK -ne 0 ]; then
  echo "$GH_PREFIX ⚠️  Not logged into GitHub CLI"
  echo "$GH_PREFIX    This is not going to work — we need GitHub CLI to work!"
  echo "$GH_PREFIX    1) Run 'gh auth login -s project' to login with OAuth and get sufficient permissions"
  echo "$GH_PREFIX    2) Grab the token with 'gh auth token' and store it on your your host's profile (~/.profile or ~/.zprofile) as \$GH_TOKEN:"
  echo "$GH_PREFIX.   3) Make sure your 'devcontainer.json' imports it:"
  echo "$GH_PREFIX      \"remoteEnv\": {"
  echo "$GH_PREFIX         \"GH_TOKEN\": \"\${localEnv:GH_TOKEN}\""
  echo "$GH_PREFIX      }"
  echo "$GH_PREFIX    4) Rebuild the devcontainer"      

  echo "$GH_PREFIX ❌ FAILURE"
  return 1
fi
echo "$GH_PREFIX Installing the TakT gh cli extension from devx-cafe/gh-tt"
gh extension install devx-cafe/gh-tt   >/dev/null 2>&1 || true
echo "$GH_PREFIX Installing the gh tt shorthand aliases" 
gh alias set semver '!gh tt semver "$@"' --clobber >/dev/null 2>&1 || true
gh alias set workon '!gh tt workon "$@"' --clobber >/dev/null 2>&1 || true
gh alias set wrapup '!gh tt wrapup "$@"' --clobber >/dev/null 2>&1 || true
gh alias set deliver '!gh tt deliver "$@"' --clobber >/dev/null 2>&1 || true
gh alias set responsibles '!gh tt responsibles "$@"' --clobber >/dev/null 2>&1 || true
echo "$GH_PREFIX ✅ TakT CLI extension setup complete"

return 0


