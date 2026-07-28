# shellcheck shell=bash
# Machine-local, opt-in worker Git identity contract.
#
# The file named worker-git-identity is deliberately local and gitignored. This
# library validates its deterministic Git-config-shaped schema, verifies the
# configured public key fingerprint, and writes only task-local public signing
# metadata. It never reads or copies the private signing key.

FM_WORKER_GIT_IDENTITY_CONFIGURED=0
FM_WORKER_GIT_IDENTITY_CONFIG=
FM_WORKER_GIT_NAME=
FM_WORKER_GIT_EMAIL=
FM_WORKER_GIT_SIGNING_KEY=
FM_WORKER_GIT_FINGERPRINT=
FM_WORKER_GIT_PRINCIPAL=
FM_WORKER_GIT_FORMAT=
FM_WORKER_GIT_SIGN=
FM_WORKER_GIT_IDENTITY_ERROR=

fm_worker_git_identity_file_safe() {
  local path=$1 links
  [ -f "$path" ] && [ ! -L "$path" ] || return 1
  links=$(stat -f %l "$path" 2>/dev/null || stat -c %h "$path" 2>/dev/null) || return 1
  [ "$links" = 1 ]
}

fm_worker_git_identity_fail() {
  FM_WORKER_GIT_IDENTITY_ERROR=$1
  return 1
}

fm_worker_git_identity_value() {
  local config=$1 key=$2 count value
  count=$(git config --file "$config" --get-all "$key" 2>/dev/null | awk 'END { print NR + 0 }')
  [ "$count" = 1 ] || return 1
  value=$(git config --file "$config" --get "$key" 2>/dev/null) || return 1
  [ -n "$value" ] || return 1
  printf '%s\n' "$value"
}

fm_worker_git_identity_public_key_line() {
  local key=$1
  awk '
    /^[[:space:]]*#/ || NF == 0 { next }
    { count++; if (NF < 2) bad=1; else value=$1 " " $2 }
    END { if (count != 1 || bad) exit 1; print value }
  ' "$key"
}

fm_worker_git_identity_validate_schema() {
  local config=$1 key value actual count
  [ -f "$config" ] && [ ! -L "$config" ] \
    || { fm_worker_git_identity_fail "worker-git-identity must be a regular non-symlink file"; return 1; }
  fm_worker_git_identity_file_safe "$config" \
    || { fm_worker_git_identity_fail "worker-git-identity has unsafe link metadata"; return 1; }
  git config --file "$config" --list >/dev/null 2>&1 \
    || { fm_worker_git_identity_fail "worker-git-identity is not valid Git configuration"; return 1; }

  while IFS= read -r key; do
    case "$key" in
      worker.name|worker.email|worker.signingkey|worker.fingerprint|worker.principal|gpg.format|commit.gpgsign) ;;
      *) fm_worker_git_identity_fail "worker-git-identity contains unsupported key $key"; return 1 ;;
    esac
  done <<EOF
$(git config --file "$config" --list --name-only 2>/dev/null)
EOF

  FM_WORKER_GIT_NAME=$(fm_worker_git_identity_value "$config" worker.name) \
    || { fm_worker_git_identity_fail "worker.name must have exactly one non-empty value"; return 1; }
  FM_WORKER_GIT_EMAIL=$(fm_worker_git_identity_value "$config" worker.email) \
    || { fm_worker_git_identity_fail "worker.email must have exactly one non-empty value"; return 1; }
  FM_WORKER_GIT_SIGNING_KEY=$(fm_worker_git_identity_value "$config" worker.signingKey) \
    || { fm_worker_git_identity_fail "worker.signingKey must have exactly one non-empty value"; return 1; }
  FM_WORKER_GIT_FINGERPRINT=$(fm_worker_git_identity_value "$config" worker.fingerprint) \
    || { fm_worker_git_identity_fail "worker.fingerprint must have exactly one non-empty value"; return 1; }
  FM_WORKER_GIT_PRINCIPAL=$(fm_worker_git_identity_value "$config" worker.principal) \
    || { fm_worker_git_identity_fail "worker.principal must have exactly one non-empty value"; return 1; }
  FM_WORKER_GIT_FORMAT=$(fm_worker_git_identity_value "$config" gpg.format) \
    || { fm_worker_git_identity_fail "gpg.format must have exactly one non-empty value"; return 1; }
  FM_WORKER_GIT_SIGN=$(git config --file "$config" --type bool --get commit.gpgSign 2>/dev/null) \
    || { fm_worker_git_identity_fail "commit.gpgSign must have exactly one boolean value"; return 1; }
  count=$(git config --file "$config" --get-all commit.gpgSign 2>/dev/null | awk 'END { print NR + 0 }')
  [ "$count" = 1 ] \
    || { fm_worker_git_identity_fail "commit.gpgSign must have exactly one boolean value"; return 1; }

  case "$FM_WORKER_GIT_NAME" in *$'\n'*|*$'\r'*|*$'\t'*) fm_worker_git_identity_fail "worker.name contains a control character"; return 1 ;; esac
  case "$FM_WORKER_GIT_EMAIL" in *$'\n'*|*$'\r'*|*$'\t'*|*' '*) fm_worker_git_identity_fail "worker.email contains whitespace or a control character"; return 1 ;; esac
  case "$FM_WORKER_GIT_SIGNING_KEY" in
    /*) ;;
    *) fm_worker_git_identity_fail "worker.signingKey must be an absolute path"; return 1 ;;
  esac
  case "$FM_WORKER_GIT_FINGERPRINT" in
    SHA256:[A-Za-z0-9+/=]*) ;;
    *) fm_worker_git_identity_fail "worker.fingerprint is not a SHA256 fingerprint"; return 1 ;;
  esac
  case "$FM_WORKER_GIT_PRINCIPAL" in
    ''|*[!A-Za-z0-9._+@:-]*) fm_worker_git_identity_fail "worker.principal contains unsupported characters"; return 1 ;;
  esac
  [ "$FM_WORKER_GIT_FORMAT" = ssh ] \
    || { fm_worker_git_identity_fail "gpg.format must be ssh"; return 1; }
  [ "$FM_WORKER_GIT_SIGN" = true ] \
    || { fm_worker_git_identity_fail "commit.gpgSign must be true"; return 1; }
  fm_worker_git_identity_file_safe "$FM_WORKER_GIT_SIGNING_KEY" \
    || { fm_worker_git_identity_fail "worker.signingKey must be a regular non-symlink file"; return 1; }
  actual=$(ssh-keygen -lf "$FM_WORKER_GIT_SIGNING_KEY" -E sha256 2>/dev/null \
    | awk 'NF >= 2 { count++; value=$2 } END { if (count != 1) exit 1; print value }') \
    || { fm_worker_git_identity_fail "worker.signingKey is not one valid public SSH key"; return 1; }
  [ "$actual" = "$FM_WORKER_GIT_FINGERPRINT" ] \
    || { fm_worker_git_identity_fail "worker.fingerprint does not match worker.signingKey"; return 1; }
  fm_worker_git_identity_public_key_line "$FM_WORKER_GIT_SIGNING_KEY" >/dev/null \
    || { fm_worker_git_identity_fail "worker.signingKey does not contain one authorized public key"; return 1; }
}

# fm_worker_git_identity_load <config-dir>
# Absence is the generic compatibility path. Presence is strict and fail-closed.
fm_worker_git_identity_load() {
  local config_dir=${1:-} config
  FM_WORKER_GIT_IDENTITY_CONFIGURED=0
  # shellcheck disable=SC2034
  FM_WORKER_GIT_IDENTITY_ERROR=
  # shellcheck disable=SC2034
  FM_WORKER_GIT_IDENTITY_CONFIG=
  config="${config_dir%/}/worker-git-identity"
  if [ ! -e "$config" ] && [ ! -L "$config" ]; then
    return 0
  fi
  fm_worker_git_identity_validate_schema "$config" || return 1
  FM_WORKER_GIT_IDENTITY_CONFIGURED=1
  # shellcheck disable=SC2034
  FM_WORKER_GIT_IDENTITY_CONFIG=$config
}

fm_worker_git_identity_host_global_config() {
  git config --global --show-origin --list 2>/dev/null \
    | awk -F '\t' '$1 ~ /^file:/ { sub(/^file:/, "", $1); print $1; exit }'
}

fm_worker_git_identity_destination_safe() {
  local path=$1
  if [ -L "$path" ] || { [ -e "$path" ] && [ ! -f "$path" ]; }; then
    return 1
  fi
}

fm_worker_git_identity_write_allowed_signers() {
  local allowed=$1 key_line old_umask
  [ "$FM_WORKER_GIT_IDENTITY_CONFIGURED" = 1 ] || return 1
  fm_worker_git_identity_destination_safe "$allowed" || return 1
  key_line=$(fm_worker_git_identity_public_key_line "$FM_WORKER_GIT_SIGNING_KEY") || return 1
  old_umask=$(umask)
  umask 077
  : > "$allowed" || { umask "$old_umask"; return 1; }
  printf '%s %s\n' "$FM_WORKER_GIT_PRINCIPAL" "$key_line" > "$allowed" || { umask "$old_umask"; return 1; }
  chmod 0600 "$allowed" || { umask "$old_umask"; return 1; }
  umask "$old_umask"
}

# fm_worker_git_identity_write_task_config <gitconfig> <allowed-signers-file>
# The generated files contain no private key or credential. The host global file
# is included read-only, then the validated worker identity overrides it.
fm_worker_git_identity_write_task_config() {
  local config=$1 allowed=$2 host_config old_umask
  [ "$FM_WORKER_GIT_IDENTITY_CONFIGURED" = 1 ] || return 1
  fm_worker_git_identity_destination_safe "$config" || return 1
  fm_worker_git_identity_destination_safe "$allowed" || return 1
  host_config=$(fm_worker_git_identity_host_global_config || true)
  if [ -n "$host_config" ] && [ ! -f "$host_config" ]; then
    host_config=
  fi
  fm_worker_git_identity_write_allowed_signers "$allowed" || return 1
  old_umask=$(umask)
  umask 077
  : > "$config" || { umask "$old_umask"; return 1; }
  if [ -n "$host_config" ]; then
    git config --file "$config" --add include.path "$host_config" || { umask "$old_umask"; return 1; }
  fi
  git config --file "$config" user.name "$FM_WORKER_GIT_NAME" || { umask "$old_umask"; return 1; }
  git config --file "$config" user.email "$FM_WORKER_GIT_EMAIL" || { umask "$old_umask"; return 1; }
  git config --file "$config" gpg.format ssh || { umask "$old_umask"; return 1; }
  git config --file "$config" user.signingKey "$FM_WORKER_GIT_SIGNING_KEY" || { umask "$old_umask"; return 1; }
  git config --file "$config" commit.gpgSign true || { umask "$old_umask"; return 1; }
  git config --file "$config" gpg.ssh.allowedSignersFile "$allowed" || { umask "$old_umask"; return 1; }
  chmod 0600 "$config" || { umask "$old_umask"; return 1; }
  umask "$old_umask"
}
