#!/bin/zsh

set -u

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"

common_script_dir="${0:A:h}"
repo_root="${common_script_dir:h:h}"
chezmoi_source="${repo_root}/chezmoi"
backup_root="${HOME}/.local/state/mac-config-sync/backups"

accepted_names=(ghostty zsh git ssh)

die() {
  print -u2 -- "error: $*"
  exit 1
}

info() {
  print -- "$*"
}

require_command() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || die "required command not found: ${name}"
}

confirm() {
  local prompt="$1"
  local answer
  while true; do
    printf "%s [y/N] " "$prompt"
    read -r answer
    case "$answer" in
      y|Y|yes|YES) return 0 ;;
      ""|n|N|no|NO) return 1 ;;
      *) print -- "Please answer y or n." ;;
    esac
  done
}

choose_conflict_action() {
  local target="$1"
  local answer
  while true; do
    print -u2 -- ""
    print -u2 -- "Conflict at ${target}"
    print -u2 -- "1. skip"
    print -u2 -- "2. replace with backup"
    print -u2 -- "3. merge"
    printf "Choose [1/2/3]: " >&2
    read -r answer
    case "$answer" in
      1|skip) print -- "skip"; return 0 ;;
      2|replace|overwrite) print -- "replace"; return 0 ;;
      3|merge) print -- "merge"; return 0 ;;
      *) print -u2 -- "Please choose 1, 2, or 3." ;;
    esac
  done
}

expand_home() {
  local file_path="$1"
  print -- "${file_path/#\~/${HOME}}"
}

ensure_parent_dir() {
  local file_path="$1"
  mkdir -p "${file_path:h}"
}

looks_sensitive_or_org() {
  local file="$1"
  [ -f "$file" ] || return 1
  LC_ALL=C grep -Eiq 'token|secret|password|passwd|private[ _-]?key|BEGIN .*PRIVATE KEY|_authToken|byted|byt|code\.byted|git\.byted|gitr|bnpm|DevEco|HarmonyOS|HDC_SERVER_PORT|OHPM_HOME' "$file"
}

template_home_paths() {
  local file="$1"
  local escaped_home="${HOME//\//\\/}"
  sed "s/${escaped_home}/{{ .chezmoi.homeDir }}/g" "$file"
}

run_chezmoi() {
  require_command chezmoi
  chezmoi --source="$chezmoi_source" --destination="$HOME" "$@"
}

backup_file() {
  local target="$1"
  local run_id="$2"
  local backup_path="${backup_root}/${run_id}${target}"
  ensure_parent_dir "$backup_path"
  cp -p "$target" "$backup_path"
  print -- "$backup_path"
}

software_available() {
  local name="$1"
  case "$name" in
    ghostty)
      [ -d "/Applications/Ghostty.app" ] || [ -d "${HOME}/Applications/Ghostty.app" ]
      ;;
    zsh)
      command -v zsh >/dev/null 2>&1
      ;;
    git)
      command -v git >/dev/null 2>&1
      ;;
    ssh)
      command -v ssh >/dev/null 2>&1
      ;;
    *)
      return 1
      ;;
  esac
}
