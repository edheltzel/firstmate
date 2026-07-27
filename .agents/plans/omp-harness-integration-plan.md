---
title: Experimental OMP worker spike and gated first-class support plan
type: feat
date: 2026-07-27
artifact_contract: ce-unified-plan/v1
artifact_readiness: experimental-spike-authorized-first-class-blocked
product_contract_source: ce-plan-bootstrap
execution: code
---

# Experimental OMP worker spike and gated first-class support plan

## Decision and scope

The Red Team disposition is BLOCK for first-class or verified OMP support.

This plan authorizes only a bounded experimental worker-only spike.

The spike is explicitly opt-in, temporary-home scoped, tmux-only, and unverified.

The spike does not add `omp` to any verified-harness allowlist, normal dispatch profile, primary supervision protocol, secondmate path, recovery or liveness claim, or Herdr support claim.

The first-class support track remains a future gated plan and is not implemented by this task.

The experimental label is part of the user-visible and agent-visible contract.

## Evidence baseline

The evidence reports were read in full before this plan correction.

The preserved incomplete plan is `fm/checkpoint-incomplete-omp-plan-c3:.agents/plans/omp-harness-integration-plan.md` at commit `4a0f3b2`.

The current Firstmate baseline is `main` at commit `c6f4424` when this plan is corrected.

The installed OMP executable is `/Users/ed/.bun/bin/omp`.

The executable resolves to `/Users/ed/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js`.

The package is `@oh-my-pi/pi-coding-agent` version `17.1.5`.

The observed Bun version is `1.3.14`.

The pinned package manifest SHA-256 is `3574ab69ffc6108192110a87e8fa07edae67892fe2519b4d33c917c798c6a405`.

The pinned CLI SHA-256 is `9898943d1ac04994ed2747d0bcce9ce6e736ee0f04d00b51833294ef5d179f3b`.

The reproducible identity commands are `command -v omp`, `readlink /Users/ed/.bun/bin/omp`, `omp --version`, `shasum -a 256 <package>/package.json <package>/dist/cli.js`, and `bun --version`.

The installed command surface includes `omp launch [MESSAGES...] [FLAGS]` and `omp launch --help` exits zero with `USAGE $ omp launch [MESSAGES...] [FLAGS]`.

The relevant launch flags are `--model`, `--profile`, `--cwd`, `--mode`, `--no-session`, `--thinking`, `--extension`, `--no-extensions`, `--no-skills`, `--no-rules`, `--auto-approve`, and `--approval-mode`.

The prior report's claim that `omp launch` does not exist is corrected to the pinned runtime observation above.

The exact current launch vector must be recorded by the implementation evidence rather than inferred from generic OMP documentation.

## Material Red Team corrections

OMP host identity is based on the resolved executable and `bun ... omp` argv ancestry, not on environment markers.

The OMP host was observed without `OMPCODE` and without `CLAUDECODE`.

OMP sets both `OMPCODE=1` and `CLAUDECODE=1` for spawned child shells, which is child-process data and not host identity.

The mixed child markers must never cause a Claude child under OMP to be classified as the OMP host.

The preserved plan's unconditional marker-precedence premise and the current-code audit's corresponding U2 row are stale and are not implementation authority.

`--no-extensions` currently removes explicit `--extension` paths despite its help text claiming that explicit paths still work.

The spike must not pass `--no-extensions` together with a required explicit extension.

The safe spike launch instead uses a fresh profile and HOME, a clean temporary OMP project root, cleared `PI_CONFIG_DIR` and `PI_CODING_AGENT_DIR`, and a pre-launch audit of project, user, and plugin discovery inputs.

The clean-root workaround is a bounded experimental precondition and is not evidence that general OMP ambient discovery is safe.

An extension failure can be visible while OMP still reaches `ready`, so RPC readiness is not the extension health signal.

The required extension must publish an exact startup handshake before the worker brief is sent.

The launcher must abort before work on missing, failed, duplicate, unexpected, replaced, path-mismatched, owner-mismatched, mode-mismatched, or hash-mismatched registration.

The handshake must bind the canonical extension path, expected content hash, task token, and exact registration set.

The worker must verify `get_state` effective thinking against the requested level before sending the brief.

An unsupported requested level, including `max` becoming `xhigh`, is a launch failure rather than a successful downgrade.

Native `turn_end` and `agent_end.isTerminal` observations are primitive runtime evidence until the Firstmate extension owns them in an integrated worker run.

The adapter must distinguish per-turn completion from terminal task completion.

The adapter must treat an RPC acknowledgement as queue acceptance, not proof that a follow-up started or completed.

The future first-class contract must test follow-up suppression after interrupt, provider or tool error, invalid transcript tails, slow streaming, and queued-message state.

The future first-class contract must own a continuation budget below OMP's runtime cap of eight and must surface handler throw, timeout, abort, and budget exhaustion as typed visible failures.

The future first-class contract must not interpret a present `session_stop` signal object as proof of interruption.

The omitted current-code surfaces are the secondmate positional parser at `bin/fm-spawn.sh:449-466`, the raw-launch escape hatch, the generated hook path around `bin/fm-spawn.sh:1222-1323`, `bin/fm-send.sh:194-227`, continuity pretool and turn-end ownership, and all cleanup lists.

The cleanup inventory includes nested hooks and state, top-level hooks and state, task temporary roots, PR poll artifacts, generated extensions, watcher processes, backend processes, and secondmate-home artifacts.

The full existing `tests/*.test.sh` loop is the regression gate, not only the shortened OMP target list.

Pi code is behavioral reference only until OMP-native API and event equivalence is separately proven.

The narrow Herdr observation that version `0.7.5-preview` recognized a Bun OMP process as an idle agent is a surviving prerequisite fact, not Herdr support evidence.

The plan distinguishes an experimental tmux worker state from a first-class verified state.

No skipped, mocked, inferred, or inconclusive row may be labeled verified.

## Experimental worker slice

### User-facing contract

The entry point is a separately named opt-in experimental command and is not a harness name accepted by `fm-harness.sh` or `fm-spawn.sh`.

The command requires an explicit temporary `FM_HOME` and refuses the active firstmate home, the repository root, and any non-temporary home.

The command launches only a task worker and has no primary, secondmate, multi-home, recovery, or Herdr mode.

The command uses only a dedicated tmux socket and a task-specific tmux session.

The command uses OMP RPC as the lifecycle and control surface.

The command does not use terminal text as completion truth.

The command launches without a positional task prompt, performs startup checks, and sends the brief only after the handshake and effective-state checks pass.

The command requires the pinned OMP executable and package identity before the extension is loaded.

The command records safe, redacted evidence containing version, hashes, allowlisted argv tokens, process ancestry, handshake, state, stream, terminal, abort, and cleanup observations.

The command labels every result `experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support`.

### Startup isolation

The launcher creates a fresh HOME, XDG config, XDG data, XDG state, and XDG cache tree below the temporary task root.

The launcher sets a unique `OMP_PROFILE` and leaves `PI_PROFILE` unset.

The launcher removes `PI_CONFIG_DIR` and `PI_CODING_AGENT_DIR` from the child environment.

The launcher creates an empty temporary OMP project root and passes it through `--cwd`.

The pre-launch audit rejects project `.omp/settings.json`, profile `settings.json` extension entries, enabled plugin roots, symlinked extension paths, and any discovered extension input other than the generated canonical file.

The generated extension directory is mode `0700` and the generated extension is mode `0400`.

The launcher never passes the contradicted `--no-extensions` and explicit-extension combination.

The launcher rechecks the generated path, owner, mode, canonical path, and hash after OMP startup before work is sent.

The extension handshake includes its own expected hash literal, so replacement between preflight and import cannot silently satisfy the expected registration record.

### Runtime and lifecycle acceptance

The launcher proves the exact pinned binary, package, version, and command surface.

The launcher captures OMP host argv and parent ancestry and proves that host identity does not depend on child markers.

The launcher requires exactly one generated extension factory registration and the exact expected event registration set.

The launcher rejects missing or failed handshake and kills the tmux task before the brief is delivered.

The launcher rejects duplicate explicit extension arguments before process startup.

The launcher rejects unexpected registration names and a handshake for another task token.

The launcher rejects extension replacement, path aliasing, owner or mode drift, and post-start hash drift.

The launcher queries `get_state` and rejects any effective model or thinking level that differs from the request.

The normal scenario sends one real RPC prompt to a local unauthenticated mock OpenAI-compatible stream and requires streamed assistant output, one `turn_end`, and one terminal `agent_end` with `isTerminal:true`.

The abort scenario sends one real RPC prompt to a deliberately slow stream, issues `abort` after the stream starts, and requires an abort acknowledgement plus a terminal event or a typed process failure before cleanup.

The launcher treats missing terminal event, duplicate turn signal, hidden extension error, follow-up acknowledgement without delivery, and normal-looking stop after an error as failures.

The launcher records the effective thinking level from OMP state rather than trusting the launch flag.

### Firstmate cleanup acceptance

The launcher publishes task metadata in the isolated home's state directory before starting OMP.

The metadata records the experimental marker, task temporary root, generated extension, tmux socket, tmux session, and isolated run root.

The launcher invokes `bin/fm-teardown.sh` for both normal and abort outcomes.

The teardown path terminates the recorded tmux session before removing the task files.

The teardown path removes the generated extension, task state, temporary files, RPC logs, isolated OMP profile, and tmux socket.

The post-cleanup assertions prove that the OMP process, tmux session, extension, state metadata, task temporary root, and isolated HOME are absent.

The cleanup path preserves existing dirty and unlanded work safeguards because the experimental task has no project worktree to discard.

The cleanup path does not invoke normal dispatch, secondmate-home cleanup, PR cleanup, watcher recovery, or Herdr operations.

## Future first-class track

The future first-class track is blocked until every S0 gate below passes on the current pinned runtime.

First-class activation requires a separately versioned evidence ledger and a fresh review after runtime or package changes.

First-class activation must add OMP to every verified-harness decision site atomically only after the complete ledger passes.

First-class activation must prove primary supervision, persistent secondmate ownership, two-home event isolation, recovery, tmux, Herdr, and complete cleanup.

First-class activation must update `AGENTS.md`, `docs/configuration.md`, `harness-adapters`, supervision protocols, launch mechanics, and all current test owners together.

First-class activation must not alias OMP to Pi or reuse Pi extension modules without native equivalence evidence.

First-class activation must preserve unknown-is-not-dead and must never respawn an unknown Bun or wrapper process.

### S0 gates

The CLI identity gate must reconcile `omp launch --help` and record exact package, executable, version, Bun, and hashes.

The discovery gate must either obtain a runtime fix that separates ambient discovery from explicit extensions or prove an equivalent immutable and complete discovery audit.

The host identity gate must use executable and argv ancestry and must pass mixed child-marker, nested shell, PID reuse, and lock-holder tests.

The extension gate must fail before work on every missing, failed, duplicate, unexpected, or replaced required extension.

The RPC gate must cover protocol negotiation, ready, prompt acknowledgement, streamed events, `turn_end`, terminal `agent_end`, state, follow-up, steer, abort, abort-and-prompt, invalid input, process exit, and resume.

The continuation gate must test handler throw, timeout, abort, repeated continuation, hidden runtime cap, lower Firstmate budget, reset, and one visible failure per supervised cycle.

The follow-up gate must prove eventual turn start after idle, streaming, interrupt, provider or tool error, invalid transcript tail, and queue suppression, or record a durable typed delivery failure.

The backend gate must prove tmux and Herdr ready, prompt, stream, follow-up, steer, abort, exit, resume, idle, and dead-owner semantics before either is called supported.

The ownership gate must prove two isolated `FM_HOME` homes, separate locks, state, extensions, watchers, projects, and wake destinations with no duplicate owner after recovery.

The cleanup gate must exercise nested hooks and state, top-level hooks and state, task temporary roots, PR poll artifacts, generated extensions, watcher and backend processes, secondmate homes, dirty work, unlanded work, and unresolved decisions.

The regression gate must run every `tests/*.test.sh` script, focused OMP tests, `bin/fm-lint.sh` for shell changes, and the repository validation owner.

## Current-code integration map

The current harness identity owner is `bin/fm-harness.sh`, but this task does not edit it.

The current lock owner is `bin/fm-lock.sh`, but this task does not edit it.

The current dispatch and launch owners are `bin/fm-bootstrap.sh`, `bin/fm-dispatch-select.sh`, and `bin/fm-spawn.sh`, but this task does not add an OMP profile or template.

The current secondmate positional parser is `bin/fm-spawn.sh:449-466`, and future first-class work must test it explicitly.

The current raw launch escape hatch is an intentionally unverified path and remains unchanged by this task.

The current generated worker hook owner is `bin/fm-spawn.sh:1222-1323`, and this experimental path is separate because normal spawn must not accept OMP.

The current send owner is `bin/fm-send.sh:194-227`, and future first-class follow-up work must prove its OMP interaction rather than assuming RPC acknowledgement is delivery.

The current continuity owners are `docs/watcher-continuity.md`, the continuity pretool checker, `bin/fm-turnend-guard.sh`, and the tracked native primary integrations.

The current cleanup owner is `bin/fm-teardown.sh`, which this spike extends only for recorded experimental metadata and otherwise leaves generic cleanup behavior unchanged.

The current recovery owners are `bin/fm-crew-state.sh`, `bin/fm-bootstrap.sh`, and the recovery skills, and this spike makes no recovery claim.

## Verification record contract

The implementation evidence must include the date, exact OMP binary, package, version, Bun version, package hashes, exact command tokens, backend, expected result, observed result, and exit status.

The evidence must redact credentials and retain only allowlisted argv tokens and environment variable names.

The evidence must state that OMP was not added to a verified-harness allowlist, dispatch profile, supervision protocol, secondmate path, recovery classifier, or Herdr claim.

The evidence must include the normal streamed turn, abort or error path, effective thinking state, host ancestry, handshake, and cleanup assertions.

The evidence must preserve the exact `omp launch --help` result and the fact that `--no-extensions` was not used with the required explicit extension.

The evidence artifact belongs in the task's durable validation location after the implementation worker has completed it and before repository validation is considered complete.

## Commit and validation sequence

The plan correction is one focused documentation commit before any implementation commit.

The experimental worker implementation is a separate focused commit.

The cleanup integration and focused tests are separate focused commits when they are independently coherent.

The verification documentation is a separate focused commit after live evidence is captured.

The implementation worker runs focused tests after each coherent change.

The implementation worker runs `for test_file in tests/*.test.sh; do bash "$test_file"; done` as the complete existing test loop.

The implementation worker runs `bin/fm-lint.sh` because shell files change.

The implementation worker rebases onto current `main` before the final clean-branch check.

The branch is ready only when it is clean, contains focused incremental commits, and remains a local fast-forward candidate.

## Definition of done

The plan correction is committed separately from implementation changes.

The experimental worker path is explicitly opt-in, isolated-home scoped, tmux-only, and labeled unverified.

The worker proves pinned runtime identity, executable and argv ancestry, mandatory handshake, effective thinking state, one normal streamed turn, one abort or error path, and real task cleanup.

No first-class, primary, secondmate, multi-home, recovery, or Herdr support claim is added.

Focused tests prove every implemented contract.

The complete existing test loop and applicable shell lint pass.

Verification documentation records the exact date, versions, commands, and output.

The branch is rebased onto current `main`, clean, and ready for guarded local fast-forward review.

## Hard stop conditions

Stop with `blocked:` if ambient extension discovery cannot be excluded without relying on the broken `--no-extensions` and explicit-extension combination.

Stop if a required extension can fail while OMP reaches ready or accepts work.

Stop if host identity depends on mixed child markers.

Stop if effective thinking differs from the requested policy without an explicit reject or map.

Stop if a continuation, follow-up, frame, terminal event, or cleanup failure can look like success.

Stop if tmux reports an OMP owner as unknown and the implementation treats unknown as alive or dead.

Stop if any implementation path broadens scope to primary supervision, secondmates, multiple homes, recovery, or Herdr.

Stop rather than weakening any Red Team S0 gate to finish the experimental spike.
