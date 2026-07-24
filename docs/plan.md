# Software Configuration Sync Plan

## Goal

Synchronize selected personal software configuration from this Mac to other devices through a dedicated private GitHub repository. The first version does not install software; if required software is missing on a target device, its configuration is skipped and reported.

## First-Version Scope

Accepted configuration:

- Ghostty: `~/.config/ghostty/config`
- Zsh: cleaned and templated personal parts of `~/.zshrc` and `~/.zprofile`
- Git: personal aliases and behavior settings from `~/.gitconfig`
- SSH: personal Host rules for `myberry.local`, `github.com`, and `Host *`

Excluded configuration:

- Organization configuration, including internal registries, domains, usernames, URL rewrites, network paths, and proprietary toolchains
- Secrets, including tokens, passwords, private keys, npm/PyPI credentials, and SSH keys
- Application state, including caches, logs, history, queues, sockets, known hosts, databases, and login state
- Skipped candidates: opencode, Raycast, ncm-cli, mole, mpv, uv, ai-dino-in-terminal, iTerm2, configstore

## Repository Model

Use a dedicated private GitHub repository as the sync repository. The user creates it manually and gives the tool its URL. The tool verifies access but does not create the repository, commit changes, or push changes.

Use chezmoi as the configuration sync engine. Custom code handles shallow scanning, user review, orchestration, missing-software reporting, and conflict policy.

Proposed repository layout:

```text
mac-config-sync/
  chezmoi/
  scripts/
    capture.zsh
    apply.zsh
  config/
    software.yaml
  docs/
    decisions/
```

The `capture.zsh` and `apply.zsh` scripts use `#!/bin/zsh` shebangs and can be executed directly after `chmod +x`, or run explicitly with `zsh scripts/capture.zsh`.

## Capture Flow

1. Shallow-scan known locations for configuration candidates without reading file contents.
2. Ask the user whether to inspect each candidate.
3. For accepted candidates, read only the required content and check for secrets, organization configuration, machine-specific paths, and application state.
4. Write accepted personal configuration into the local sync repository in chezmoi-compatible form.
5. Show the sync repository diff.
6. Leave commit and push to the user.

## Apply Flow

1. Clone or open the private sync repository.
2. Detect whether each target software package is installed.
3. Skip configuration for unavailable target software and include it in the final report.
4. For existing target files, show a diff and ask the user to skip, replace with backup, or merge.
5. Use an external merge tool for merge decisions.
6. Apply accepted changes through chezmoi.
7. Report applied, skipped, missing-software, and conflict outcomes.

## Implementation Decisions

- The orchestration tool is implemented as `zsh` scripts with `#!/bin/zsh` shebangs.
- `chezmoi/` contains the source state that maps to user-home target files.
- CLI availability is detected with `command -v`; Ghostty availability is detected through common `.app` locations.
- Merge conflicts use an external merge tool selected from `MERGE_TOOL`, `VISUAL`, `EDITOR`, or `vimdiff`.
