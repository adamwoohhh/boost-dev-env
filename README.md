# Mac Config Sync

Synchronize selected personal software configuration to other Macs through a dedicated private GitHub repository.

This first version synchronizes configuration only. It does not install software. If a target Mac does not have the software needed for a configuration item, that item is skipped and reported.

## Prerequisites

- A manually created private GitHub repository for this tool.
- `zsh`.
- `git`.
- `chezmoi`.

## Repository Layout

```text
chezmoi/              # chezmoi source state
scripts/
  capture.zsh         # capture accepted local configuration
  apply.zsh           # apply accepted configuration on another Mac
config/
  software.yaml       # supported software metadata
docs/
  adr/                # decisions
```

## Capture

Run this on the source Mac:

```sh
./scripts/capture.zsh
```

The script scans the supported candidates, asks before inspecting them, filters organization configuration and secrets, writes accepted configuration into `chezmoi/`, and shows the resulting diff. It does not commit or push changes.

After review:

```sh
git add chezmoi config docs README.md scripts
git commit -m "Capture personal Mac configuration"
git push
```

## Apply

Run this on a target Mac from a checkout of the private repository:

```sh
./scripts/apply.zsh
```

The script checks whether supported software exists on the target Mac. Missing software is reported and skipped. Existing target files produce a diff and ask whether to skip, replace with backup, or merge using an external merge tool.

Backups are stored under:

```text
~/.local/state/mac-config-sync/backups/
```

Preview without writing files:

```sh
./scripts/apply.zsh --dry-run
```

Dry-run mode renders templates, reports missing software, and shows diffs for existing target files. It does not write files, create backups, or open a merge tool.

For non-interactive dry-run tests, provide the Git email template value:

```sh
MAC_CONFIG_SYNC_EMAIL=test@example.invalid ./scripts/apply.zsh --dry-run
```

## First-Version Scope

Included:

- Ghostty: `~/.config/ghostty/config`
- Zsh: cleaned personal parts of `~/.zshrc` and `~/.zprofile`
- Git: personal aliases and behavior settings from `~/.gitconfig`
- SSH: personal Host rules for `myberry.local`, `github.com`, and `Host *`

Excluded:

- Organization configuration.
- Secrets and credentials.
- SSH keys, known hosts, and agent state.
- Application state such as caches, logs, queues, sockets, history, and databases.
