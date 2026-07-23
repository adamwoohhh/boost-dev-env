# Software Configuration Sync

This context defines the shared language for synchronizing selected local software configuration to other devices through a private GitHub repository.

## Language

**Software Configuration**:
A stable, reviewable setting file or configuration directory for an installed tool or application that can be reproduced on another device.
_Avoid_: Application state, cache, history

**Configuration Candidate**:
A locally discovered software configuration item that has not yet been accepted for synchronization. Each candidate requires an explicit user decision before it becomes managed.
_Avoid_: Automatically synced config, discovered state

**Private Sync Repository**:
The private GitHub repository used as the source of truth and transport for accepted Software Configuration.
_Avoid_: Public dotfiles repo, local backup

**Unavailable Target Software**:
Software required to consume an accepted configuration but not installed on the target device. Its configuration is skipped during application and reported to the user.
_Avoid_: Install target, blocking dependency

**Accepted Configuration**:
A Configuration Candidate approved for synchronization after shallow discovery and, when needed, deeper inspection for sensitive or machine-specific content.
_Avoid_: Candidate, local-only setting

**Organization Configuration**:
Configuration tied to an employer or organization, including internal registries, domains, usernames, network paths, proprietary toolchains, and work-specific aliases. It is excluded from synchronization.
_Avoid_: Personal software configuration, accepted configuration

**Configuration Conflict**:
A target-device situation where an Accepted Configuration would write to a path that already has local content. The user resolves it after seeing a diff by skipping, replacing with backup, or merging.
_Avoid_: Automatic overwrite, silent merge
