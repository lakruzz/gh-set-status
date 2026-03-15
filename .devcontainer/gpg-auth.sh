#!/usr/bin/env bash

GPG_PREFIX="🔑    "
echo "$GPG_PREFIX Sourcing $(basename "${BASH_SOURCE[0]}")"
GPG_HOME="${GNUPGHOME:-$HOME/.gnupg}"
export GNUPGHOME="$GPG_HOME"

decode_passphrase() {
  if [ -z "${_GPG_PASSPHRASE:-}" ]; then
    GPG_PASSPHRASE=""
    return 0
  fi

  if ! GPG_PASSPHRASE=$(printf '%s' "$_GPG_PASSPHRASE" | base64 --decode 2>/dev/null); then
    echo "$GPG_PREFIX  ERROR: Failed to decode \$_GPG_PASSPHRASE as base64"
    exit 1
  fi
}

echo "$GPG_PREFIX Checking for GPG key to import"

if [ -n "${_GPG_KEY:-}" ]; then
  set -e # Fail on error
  decode_passphrase
  
  echo "$GPG_PREFIX Initializing GPG environment"
  # Kill any existing gpg-agents
  gpgconf --kill gpg-agent 2>/dev/null || true
  sleep 1
  
  # Reset gnupg home to avoid stale/broken agent config.
  rm -rf "$GPG_HOME"
  mkdir -p "$GPG_HOME"
  chmod 700 "$GPG_HOME"
  
  # Prompt once, then keep the passphrase cached by gpg-agent.
  {
    echo "pinentry-mode loopback"
  } > "$GPG_HOME/gpg.conf"

  cat > "$GPG_HOME/gpg-agent.conf" <<'EOF'
allow-loopback-pinentry
pinentry-program /usr/bin/pinentry-curses
default-cache-ttl 7200
max-cache-ttl 7200
EOF
  chmod 600 "$GPG_HOME/gpg.conf" "$GPG_HOME/gpg-agent.conf"

  
  # Start gpg-agent
  gpgconf --kill gpg-agent >/dev/null 2>&1 || true
  AGENT_ENV=$(gpg-agent --daemon --quiet 2>/dev/null || true)
  if [ -n "$AGENT_ENV" ]; then
    eval "$AGENT_ENV"
  fi
  gpg-connect-agent reloadagent /bye >/dev/null 2>&1 || true
  sleep 1
  if [ -t 0 ]; then
    export GPG_TTY="$(tty)"
    gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
  fi

  EXISTING_KEY_ID=$(gpg --homedir "$GPG_HOME" --list-secret-keys --with-colons 2>/dev/null | awk -F: '$1=="sec"{print $5; exit}')
  
  if [ -n "$EXISTING_KEY_ID" ]; then
    echo "$GPG_PREFIX Reusing existing secret key $EXISTING_KEY_ID"
    KEY_ID="$EXISTING_KEY_ID"
  else
    echo "$GPG_PREFIX Importing key into gpg keyring"
    IMPORT_OK=0
    if [ -n "$GPG_PASSPHRASE" ]; then
      echo "$GPG_PREFIX Using provided passphrase for key import"
      if printf '%s' "$_GPG_KEY" | base64 --decode | gpg --homedir "$GPG_HOME" --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" --import --quiet; then
        IMPORT_OK=1
      fi
    fi

    if [ "$IMPORT_OK" -ne 1 ]; then
      if printf '%s' "$_GPG_KEY" | base64 --decode | gpg --homedir "$GPG_HOME" --batch --yes --import --quiet; then
        IMPORT_OK=1
      fi
    fi

    if [ "$IMPORT_OK" -ne 1 ]; then
      echo "$GPG_PREFIX  ERROR: Failed to import GPG key"
      exit 1
    fi

    echo "$GPG_PREFIX Getting the KEY_ID"
    KEY_ID=$(gpg --homedir "$GPG_HOME" --list-secret-keys --with-colons 2>/dev/null | awk -F: '$1=="sec"{print $5; exit}')
  fi

  if [ -z "$KEY_ID" ]; then
    echo "$GPG_PREFIX  ERROR: No secret key found after import"
    exit 1
  fi

  echo "$GPG_PREFIX Configuring git to use GPG key $KEY_ID for signing commits"
  git config --local user.signingkey "$KEY_ID"
  git config --local commit.gpgSign true
  git config --local gpg.program gpg
  git config --local gpg.format openpgp
  
  echo "$GPG_PREFIX Setting key trust to ultimate"
  FINGERPRINT=$(gpg --homedir "$GPG_HOME" --list-secret-keys --with-colons "$KEY_ID" 2>/dev/null | awk -F: '$1=="fpr"{print $10; exit}')
  if [ -n "$FINGERPRINT" ]; then
    printf '%s:6:\n' "$FINGERPRINT" | gpg --homedir "$GPG_HOME" --import-ownertrust >/dev/null 2>&1 || true
  fi

  # Prime agent cache so the first signed commit does not prompt again.
  if [ -n "$GPG_PASSPHRASE" ]; then
    echo "$GPG_PREFIX Warm up GPG passphrase in gpg-agent"
    printf 'cache-warmup' | gpg --homedir "$GPG_HOME" --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" --local-user "$KEY_ID" --sign --armor >/dev/null 2>&1 || true
  fi

  echo "$GPG_PREFIX Ensuring shell startup exports GPG_TTY"
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  	touch "$rc"
  	grep -F 'export GPG_TTY=$(tty)' "$rc" >/dev/null 2>&1 || echo 'export GPG_TTY=$(tty)' >> "$rc"
  	grep -F 'gpgconf --launch gpg-agent >/dev/null 2>&1 || true' "$rc" >/dev/null 2>&1 || echo 'gpgconf --launch gpg-agent >/dev/null 2>&1 || true' >> "$rc"
  	grep -F 'gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true' "$rc" >/dev/null 2>&1 || echo 'gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true' >> "$rc"
  done

  echo "$GPG_PREFIX ✅ GPG setup complete"
else
  echo "$GPG_PREFIX  No \$_GPG_KEY defined - skipping GPG key import"
fi
return 0


