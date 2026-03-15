#!/usr/bin/env bash

PREFIX="🔑  "
GPG_HOME="${GNUPGHOME:-$HOME/.gnupg}"
export GNUPGHOME="$GPG_HOME"

decode_passphrase_if_needed() {
  if [ -z "${_GPG_PASSPHRASE:-}" ]; then
    return 0
  fi

  # Accept both plain text and base64-encoded passphrases.
  local decoded
  decoded=$(printf '%s' "$_GPG_PASSPHRASE" | base64 --decode 2>/dev/null || true)
  if [ -n "$decoded" ]; then
    _GPG_PASSPHRASE="$decoded"
  fi
}

echo "$PREFIX  Checking for GPG key to import"

if [ -n "${_GPG_KEY:-}" ]; then
  set -e # Fail on error
  decode_passphrase_if_needed

  # curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
  # chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
  # echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
  # apt-get update
  
  echo "$PREFIX  Initializing GPG environment"
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
    echo "$PREFIX  Reusing existing secret key $EXISTING_KEY_ID"
    KEY_ID="$EXISTING_KEY_ID"
  else
    echo "$PREFIX  Found \$_GPG_KEY - decoding with base64 and importing into gpg keyring"
    IMPORT_OK=0
    if [ -n "${_GPG_PASSPHRASE:-}" ]; then
      echo "$PREFIX  Using provided passphrase for key import"
      if printf '%s' "$_GPG_KEY" | base64 --decode | gpg --homedir "$GPG_HOME" --batch --yes --pinentry-mode loopback --passphrase "$_GPG_PASSPHRASE" --import --quiet; then
        IMPORT_OK=1
      fi
    fi

    if [ "$IMPORT_OK" -ne 1 ]; then
      if printf '%s' "$_GPG_KEY" | base64 --decode | gpg --homedir "$GPG_HOME" --batch --yes --import --quiet; then
        IMPORT_OK=1
      fi
    fi

    if [ "$IMPORT_OK" -ne 1 ]; then
      echo "$PREFIX  ERROR: Failed to import GPG key"
      exit 1
    fi

    echo "$PREFIX  Getting the KEY_ID"
    KEY_ID=$(gpg --homedir "$GPG_HOME" --list-secret-keys --with-colons 2>/dev/null | awk -F: '$1=="sec"{print $5; exit}')
  fi

  if [ -z "$KEY_ID" ]; then
    echo "$PREFIX  ERROR: No secret key found after import"
    exit 1
  fi

  echo "$PREFIX  Configuring git to use GPG key $KEY_ID for signing commits"
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git config --local user.signingkey "$KEY_ID"
    git config --local commit.gpgSign true
    git config --local gpg.program gpg
    git config --local gpg.format openpgp
  else
    git config --global user.signingkey "$KEY_ID"
    git config --global commit.gpgSign true
    git config --global gpg.program gpg
    git config --global gpg.format openpgp
  fi
  
  echo "$PREFIX  Setting key trust to ultimate"
  FINGERPRINT=$(gpg --homedir "$GPG_HOME" --list-secret-keys --with-colons "$KEY_ID" 2>/dev/null | awk -F: '$1=="fpr"{print $10; exit}')
  if [ -n "$FINGERPRINT" ]; then
    printf '%s:6:\n' "$FINGERPRINT" | gpg --homedir "$GPG_HOME" --import-ownertrust >/dev/null 2>&1 || true
  fi

  gpgconf --kill gpg-agent >/dev/null 2>&1 || true
  gpgconf --launch gpg-agent >/dev/null 2>&1 || true

  echo "$PREFIX Ensuring shell startup exports GPG_TTY"
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  	touch "$rc"
  	grep -F 'export GPG_TTY=$(tty)' "$rc" >/dev/null 2>&1 || echo 'export GPG_TTY=$(tty)' >> "$rc"
  	grep -F 'gpgconf --launch gpg-agent >/dev/null 2>&1 || true' "$rc" >/dev/null 2>&1 || echo 'gpgconf --launch gpg-agent >/dev/null 2>&1 || true' >> "$rc"
  	grep -F 'gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true' "$rc" >/dev/null 2>&1 || echo 'gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true' >> "$rc"
  done

  echo "$PREFIX ✅ GPG setup complete"
else
  echo "$PREFIX  No \$_GPG_KEY defined - skipping GPG key import"
fi
return 0


