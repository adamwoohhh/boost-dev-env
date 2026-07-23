# Do not synchronize device SSH keys

SSH host rules can be synchronized after removing organization-specific entries, but SSH private keys, public keys, known hosts, and agent state are not stored in the sync repository. New devices generate or import their own SSH identities so device trust can be registered and revoked independently.
