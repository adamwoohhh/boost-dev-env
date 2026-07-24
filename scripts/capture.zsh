#!/bin/zsh

set -u

entry_script_dir="${0:A:h}"
source "${entry_script_dir}/lib/common.zsh"

require_command awk
require_command sed
require_command git
require_command chezmoi

mkdir -p "$chezmoi_source"

captured=()
skipped=()

ensure_chezmoi_config_template() {
  local target_file="${chezmoi_source}/.chezmoi.toml.tmpl"
  [ -f "$target_file" ] && return 0

  cat > "$target_file" <<'EOF'
{{- $email := promptStringOnce . "email" "Git email" -}}

[data]
    email = {{ $email | quote }}
EOF
}

capture_ghostty() {
  local source_file="${HOME}/.config/ghostty/config"
  local target_file="${chezmoi_source}/dot_config/ghostty/config"
  [ -f "$source_file" ] || return 1

  info "Candidate: Ghostty (${source_file})"
  confirm "Inspect and capture Ghostty config?" || { skipped+=(ghostty); return 0; }
  if looks_sensitive_or_org "$source_file"; then
    info "Skipping Ghostty: sensitive or organization-like content detected."
    skipped+=(ghostty)
    return 0
  fi

  ensure_parent_dir "$target_file"
  cp "$source_file" "$target_file"
  captured+=(ghostty)
}

capture_zsh() {
  local zshrc="${HOME}/.zshrc"
  local zprofile="${HOME}/.zprofile"
  local target_zshrc="${chezmoi_source}/dot_zshrc.tmpl"
  local target_zprofile="${chezmoi_source}/dot_zprofile.tmpl"
  [ -f "$zshrc" ] || [ -f "$zprofile" ] || return 1

  info "Candidate: Zsh (${zshrc}, ${zprofile})"
  confirm "Inspect and capture cleaned Zsh config?" || { skipped+=(zsh); return 0; }

  if [ -f "$zprofile" ]; then
    ensure_parent_dir "$target_zprofile"
    awk '
      /byted|byt|bnpm|DevEco|HarmonyOS|HDC_SERVER_PORT|OHPM_HOME|token|secret|password|_authToken/ {next}
      {print}
    ' "$zprofile" | sed "s#${HOME}#{{ .chezmoi.homeDir }}#g; s#\"export HOMEBREW_AUTO_UPDATE_SECS#\"\\
export HOMEBREW_AUTO_UPDATE_SECS#g" > "$target_zprofile"
  fi

  if [ -f "$zshrc" ]; then
    ensure_parent_dir "$target_zshrc"
    awk '
      /byted|byt|bnpm|DevEco|HarmonyOS|HDC_SERVER_PORT|OHPM_HOME|token|secret|password|_authToken/ {next}
      /NVM_DIR|\.nvm|nvm\.sh|bash_completion/ {next}
      /BUN_INSTALL|\.bun|bun completions/ {next}
      {print}
    ' "$zshrc" | sed "s#${HOME}#{{ .chezmoi.homeDir }}#g; s#\"export HOMEBREW_AUTO_UPDATE_SECS#\"\\
export HOMEBREW_AUTO_UPDATE_SECS#g" > "$target_zshrc"
  fi

  if { [ -f "$target_zprofile" ] && looks_sensitive_or_org "$target_zprofile"; } ||
     { [ -f "$target_zshrc" ] && looks_sensitive_or_org "$target_zshrc"; }; then
    info "Skipping Zsh: filtered output still contains sensitive or organization-like content."
    rm -f "$target_zprofile" "$target_zshrc"
    skipped+=(zsh)
    return 0
  fi

  captured+=(zsh)
}

capture_git() {
  local target_file="${chezmoi_source}/dot_gitconfig.tmpl"
  command -v git >/dev/null 2>&1 || return 1
  git config --global --list >/dev/null 2>&1 || return 1

  info "Candidate: Git (${HOME}/.gitconfig)"
  confirm "Inspect and capture personal Git config?" || { skipped+=(git); return 0; }

  ensure_chezmoi_config_template
  ensure_parent_dir "$target_file"
  {
    print -- "# Managed personal Git configuration."
    print -- "# Organization config, credentials, safe.directory, and Git LFS filters are excluded."
    print -- ""
    git config --global --list |
      awk -F= '
        /^alias\./ {print; next}
        /^pull\./ {print; next}
        /^fetch\.prune=/ {print; next}
        /^oh-my-zsh\./ {print; next}
        /^user\.name=/ {print; next}
      ' |
      while IFS= read -r entry; do
        key="${entry%%=*}"
        value="${entry#*=}"
        section="${key%%.*}"
        rest="${key#*.}"
        subsection=""
        name="$rest"
        if [[ "$rest" == *.* ]]; then
          subsection="${rest%.*}"
          name="${rest##*.}"
        fi
        if [ -n "$subsection" ]; then
          print -- "[${section} \"${subsection}\"]"
        else
          print -- "[${section}]"
        fi
        print -- "    ${name} = ${value}"
        print -- ""
      done
    print -- "[user]"
    print -- "    email = {{ .email | quote }}"
  } > "$target_file"

  if looks_sensitive_or_org "$target_file"; then
    info "Skipping Git: filtered output still contains sensitive or organization-like content."
    rm -f "$target_file"
    skipped+=(git)
    return 0
  fi

  captured+=(git)
}

capture_ssh() {
  local source_file="${HOME}/.ssh/config"
  local target_file="${chezmoi_source}/dot_ssh/config.tmpl"
  [ -f "$source_file" ] || return 1

  info "Candidate: SSH host config (${source_file})"
  confirm "Inspect and capture personal SSH Host rules?" || { skipped+=(ssh); return 0; }

  ensure_parent_dir "$target_file"
  awk '
    function wanted(host) {
      return host == "myberry.local" || host == "github.com" || host == "*"
    }
    /^[[:space:]]*[Hh]ost[[:space:]]+/ {
      host=$0
      sub(/^[[:space:]]*[Hh]ost[[:space:]]+/, "", host)
      active=wanted(host)
    }
    active {print}
  ' "$source_file" | sed "s#${HOME}#{{ .chezmoi.homeDir }}#g" > "$target_file"

  if looks_sensitive_or_org "$target_file"; then
    info "Skipping SSH: filtered output still contains sensitive or organization-like content."
    rm -f "$target_file"
    skipped+=(ssh)
    return 0
  fi

  captured+=(ssh)
}

info "Starting capture into ${chezmoi_source}"
capture_ghostty || skipped+=(ghostty)
capture_zsh || skipped+=(zsh)
capture_git || skipped+=(git)
capture_ssh || skipped+=(ssh)

print -- ""
info "Captured: ${captured[*]:-none}"
info "Skipped: ${skipped[*]:-none}"

print -- ""
info "Repository diff:"
if git -C "$repo_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$repo_root" status --short -- chezmoi config scripts docs README.md || true
  git -C "$repo_root" diff -- chezmoi config scripts docs README.md || true
else
  find "$chezmoi_source" -type f -print
fi

print -- ""
info "Review the repository changes, then commit and push manually."
