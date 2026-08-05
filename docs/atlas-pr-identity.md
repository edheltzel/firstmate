# Atlas PR identity broker

The Atlas PR identity path is an explicit project opt-in resolved by `bin/fm-project-mode.sh --pr-identity`.

The legacy mode query remains the two-field `<mode> <yolo>` output, and projects without an identity profile return `none` from the new query.

Unknown profiles, duplicate profile tokens, reordered profile tokens, and every `local-only` combination fail before a worker is created.

The `atlas-pat` profile is supported only for `direct-PR` until the no-mistakes publication pipeline is broker-integrated, so a no-mistakes opt-in fails closed.

`bin/fm-spawn.sh` runs the broker preflight before backend or worktree mutation and records a private host binding alongside the non-secret task metadata.

The host binding is the authoritative recovery binding, and task metadata must match it on every broker lifecycle operation.

The broker requires the installed `gh-axi` version to be exactly `0.1.27`, and `tests/fixtures/gh-axi-*.golden.toon` records the local encoder contract without a network call.

Commit verification parses complete TOON item-list and tabular arrays, requires every declared row, and refuses malformed, incomplete, foreign, null, or uncompleted paginated responses.

The broker reads exactly one `ATLAS_KEY_PAT` assignment from the host environment file without sourcing or printing the file.

The broker rejects missing, duplicate, malformed, or wrong-login credentials and verifies write capability for the exact repository derived from `origin`.

The worker never receives the token in its environment, argv, brief, command, task metadata, status, log, report, or generated file.

The accepted trusted-worker threat model allows a same-user worker to inspect the host environment deliberately, so the broker is an operational guardrail rather than OS-level secret isolation.

The write surface is limited to one exact task-branch push, one exact PR creation, and post-publication verification.

The push path uses an exact HTTPS repository URL, clears inherited Git credential helpers, disables terminal prompting, and uses an inline helper that validates the GitHub host and repository before returning credentials to Git.

The broker refuses default-branch pushes, repository overrides, branch mismatches, force publication, and a remote head that differs from the verified local head.

Before publication the broker checks the exact base-to-head commit range, the configured Atlas worker author and committer fields, and a valid SSH signature on every commit. Each signature must verify through a deterministic allowed-signers record to the configured Atlas principal and fingerprint; a `gpgsig` header alone is not sufficient.

The signed worker profile is the machine-local `config/worker-git-identity` contract described in [`configuration.md`](configuration.md#worker-git-identity). The broker requires the exact Atlas author/email, SSH principal, and public-key fingerprint from that validated profile. Repository `required_signatures` responses of `true`, `false`, or the documented absent optional subresource are compatible with this local signed profile; forbidden, authentication, malformed, server, transport, and unknown policy results refuse publication.

PR verification checks the exact repository, Atlas-Key author and remote commit associations, task head branch, recorded base branch, head SHA, and commit set.

A push or create failure writes a private partial-publication record with safe remote-state and retry fields.

A successful push followed by create or verification failure persists the PR URL or remote branch state with `retry_safe=no`, preserves the remote branch, and refuses automatic deletion or retry as Ed.

Create refuses a recorded PR URL before making another request, while `reconcile <task-id> <pr-url>` is the verification-and-reset-safe recovery path and `reset <task-id> --confirm-no-pr` is limited to tasks with no recorded PR URL.

Polling and teardown use the same host-owned broker verification path without the Atlas write token.

Opted-in polling detects the REST `merged` or `merged_at` fields and reports read-authentication or identity failures instead of silently treating them as an unmerged PR.

Opted-in polling fails closed when the binding is absent, malformed, or inconsistent with metadata, and never falls back to ordinary `gh` after an identity downgrade.

Opted-in teardown retries host verification within a bounded window, preserves the worktree when landing remains unknown, and accepts an independent default-branch content proof only when that proof succeeds.

Opted-in merge requires a separate Ed-authenticated assertion and uses the REST merge endpoint with the verified PR head SHA, so a moved head is rejected atomically without falling back to unpinned `gh-axi pr merge`.

If spawn aborts after preflight but before metadata publication, it removes only the binding created by that invocation, while a published task retains its binding for recovery.

The remote Atlas Config pilot, credential cleanup, App installation, signing-key creation, pushes, and PR creation remain separate captain-authorized actions.

The exact command contracts and failure categories live in the headers and help of the scripts that implement them.
