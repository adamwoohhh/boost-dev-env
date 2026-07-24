#!/bin/zsh

set -u

entry_script_dir="${0:A:h}"
source "${entry_script_dir}/lib/common.zsh"

require_command chezmoi
require_command diff

dry_run=false
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run)
      dry_run=true
      ;;
    -h|--help)
      print -- "Usage: ./scripts/apply.zsh [--dry-run]"
      print -- ""
      print -- "Apply accepted configuration. In dry-run mode, render templates,"
      print -- "show diffs and missing software, but do not write files, back up,"
      print -- "or open merge tools."
      exit 0
      ;;
    *)
      die "unknown argument: ${arg}"
      ;;
  esac
done

run_id="$(date +%Y%m%d-%H%M%S)"
applied=()
skipped=()
missing=()
template_email=""
template_data_args=()

json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  print -- "$value"
}

prepare_template_data() {
  [ -f "${chezmoi_source}/dot_gitconfig.tmpl" ] || return 0

  if [ "$dry_run" = true ]; then
    template_email="${MAC_CONFIG_SYNC_EMAIL:-dry-run@example.invalid}"
  else
    printf "Git email: "
    read -r template_email
    [ -n "$template_email" ] || die "Git email is required for dot_gitconfig.tmpl"
  fi

  local escaped_email
  escaped_email="$(json_escape "$template_email")"
  template_data_args=(--override-data "{\"email\":\"${escaped_email}\"}")
}

targets_for() {
  local name="$1"
  case "$name" in
    ghostty) print -- "${HOME}/.config/ghostty/config" ;;
    zsh)
      print -- "${HOME}/.zprofile"
      print -- "${HOME}/.zshrc"
      ;;
    git) print -- "${HOME}/.gitconfig" ;;
    ssh) print -- "${HOME}/.ssh/config" ;;
  esac
}

source_paths_for() {
  local name="$1"
  case "$name" in
    ghostty) print -- "dot_config/ghostty/config" ;;
    zsh)
      print -- "dot_zprofile.tmpl"
      print -- "dot_zshrc.tmpl"
      ;;
    git) print -- "dot_gitconfig.tmpl" ;;
    ssh) print -- "dot_ssh/config.tmpl" ;;
  esac
}

render_source() {
  local source_path="$1"
  run_chezmoi execute-template "${template_data_args[@]}" < "${chezmoi_source}/${source_path}"
}

merge_target() {
  local target="$1"
  local desired="$2"

  info "Opening merge tool with current target and desired config."
  ${MERGE_TOOL:-${VISUAL:-${EDITOR:-vimdiff}}} "$target" "$desired"
}

handle_target_conflict() {
  local target="$1"
  local source_path="$2"
  local desired
  desired="$(mktemp)"
  render_source "$source_path" > "$desired"

  if [ ! -e "$target" ]; then
    if [ "$dry_run" = true ]; then
      info "DRY-RUN: would create ${target}"
      rm -f "$desired"
      return 2
    fi
    rm -f "$desired"
    return 0
  fi

  if cmp -s "$target" "$desired"; then
    info "No change for ${target}"
    rm -f "$desired"
    return 2
  fi

  print -- ""
  print -- "Diff for ${target}:"
  diff -u "$target" "$desired" || true

  if [ "$dry_run" = true ]; then
    info "DRY-RUN: would ask whether to skip, replace with backup, or merge ${target}"
    rm -f "$desired"
    return 2
  fi

  local action
  action="$(choose_conflict_action "$target")"
  case "$action" in
    skip)
      rm -f "$desired"
      return 1
      ;;
    replace)
      local backup
      backup="$(backup_file "$target" "$run_id")"
      info "Backed up ${target} to ${backup}"
      rm -f "$desired"
      return 0
      ;;
    merge)
      local backup
      backup="$(backup_file "$target" "$run_id")"
      info "Backed up ${target} to ${backup}"
      merge_target "$target" "$desired"
      rm -f "$desired"
      return 2
      ;;
  esac
}

apply_one() {
  local name="$1"
  if ! software_available "$name"; then
    missing+=("$name")
    return 0
  fi

  local source_paths=("${(@f)$(source_paths_for "$name")}")
  local target_paths=("${(@f)$(targets_for "$name")}")
  local any_source=false
  local index=1
  local source_path
  local did_apply=false

  for source_path in "${source_paths[@]}"; do
    [ -f "${chezmoi_source}/${source_path}" ] || { index=$((index + 1)); continue; }
    any_source=true
    local target="${target_paths[$index]}"
    handle_target_conflict "$target" "$source_path"
    local conflict_result=$?
    case "$conflict_result" in
      0)
        if [ "$dry_run" = true ]; then
          info "DRY-RUN: would apply ${target}"
        else
          run_chezmoi apply "${template_data_args[@]}" --include=files "$target"
        fi
        did_apply=true
        ;;
      1)
        skipped+=("${name}:${target}")
        ;;
      2)
        did_apply=true
        ;;
    esac
    index=$((index + 1))
  done

  if [ "$any_source" = true ]; then
    [ "$did_apply" = true ] && applied+=("$name")
  else
    skipped+=("${name}:no-source")
  fi
}

if [ "$dry_run" = true ]; then
  info "Dry-running configuration from ${chezmoi_source}"
else
  info "Applying configuration from ${chezmoi_source}"
fi
prepare_template_data
for name in "${accepted_names[@]}"; do
  apply_one "$name"
done

print -- ""
if [ "$dry_run" = true ]; then
  info "Would apply: ${applied[*]:-none}"
else
  info "Applied: ${applied[*]:-none}"
fi
info "Skipped: ${skipped[*]:-none}"
info "Missing software: ${missing[*]:-none}"
