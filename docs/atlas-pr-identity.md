# Atlas PR identity broker

The Atlas PR identity path is an explicit project opt-in resolved by `bin/fm-project-mode.sh --pr-identity`.

The legacy mode query remains the two-field `<mode> <yolo>` output, and projects without an identity profile return `none` from the new query.

Unknown profiles, duplicate profile tokens, reordered profile tokens, and every `local-only` combination fail before a worker is created.

`bin/fm-spawn.sh` runs the broker preflight before backend or worktree mutation and stores only `pr_identity`, `pr_project_key`, `pr_repo`, `pr_branch`, and `pr_base` in task metadata.

The metadata is a recovery binding, not proof of credential possession.

The broker reads exactly one `ATLAS_KEY_PAT` assignment from the host environment file without sourcing or printing the file.

The broker rejects missing, duplicate, malformed, or wrong-login credentials and verifies write capability for the exact repository derived from `origin`.

The worker never receives the token in its environment, argv, brief, command, task metadata, status, log, report, or generated file.

The accepted trusted-worker threat model allows a same-user worker to inspect the host environment deliberately, so the broker is an operational guardrail rather than OS-level secret isolation.

The write surface is limited to one exact task-branch push, one exact PR creation, and post-publication verification.

The push path uses an exact HTTPS repository URL, clears inherited Git credential helpers, disables terminal prompting, and uses an inline helper that validates the GitHub host and repository before returning credentials to Git.

The broker refuses default-branch pushes, repository overrides, branch mismatches, force publication, and a remote head that differs from the verified local head.

Before publication the broker checks the exact base-to-head commit range, Atlas author and committer fields, the repository unsigned-signature policy, and the absence of every commit signature.

PR verification checks the exact repository, Atlas-Key author, task head branch, recorded base branch, head SHA, and commit set.

A push or create failure writes a private partial-publication record with safe remote-state and retry fields.

A successful push followed by create or verification failure preserves the remote branch and refuses automatic deletion or retry as Ed.

Polling and teardown use host-owned read verification without the Atlas write token.

Opted-in polling reports read-authentication or identity failures instead of silently treating them as an unmerged PR.

Opted-in teardown disables its content fallback when host read verification cannot prove the exact merged PR.

Opted-in merge requires a separate Ed-authenticated assertion and never falls back to Atlas credentials.

The remote Atlas Config pilot, credential cleanup, App installation, signing-key creation, pushes, and PR creation remain separate captain-authorized actions.

The exact command contracts and failure categories live in the headers and help of the scripts that implement them.
