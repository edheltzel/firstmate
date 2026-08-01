Mode: OMP extension background wake.

When this session owns supervision and away mode is not active:

1. Drain first with `bin/fm-wake-drain.sh`.
2. Confirm OMP loaded both tracked Pi-compatible extensions by starting it with `-e __FM_PI_TURNEND_EXT__ -e __FM_PI_EXT__`.
3. First cycle: arm with the `fm_watch_arm_pi` tool registered by the watcher extension.
4. If the extension says no live session holds the lock, run `bin/fm-session-start.sh` to reclaim the session lock, then call `fm_watch_arm_pi` again.
5. The extension starts `bin/fm-watch-arm.sh --restart`, keeps the child attached to the live OMP process, and owns every later successor launch.
6. After an actionable child close, the extension rechecks session-lock ownership and verifies one successor before it delivers the follow-up notification.
7. Ordinary notification: do not call `fm_watch_arm_pi` again because continuity is extension-owned rather than model-memory-owned.
8. An unexpected child close enters bounded exponential retry, and an exhausted retry or lost session lock is surfaced as a monitoring failure instead of disappearing.
9. Failure or missing cycle only: drain queued notifications, inspect the failure text, call `fm_watch_arm_pi`, and restart OMP with both extensions loaded if needed.
10. Never use shell `&` for watcher supervision.

The turn-end guard extension lives at `__FM_PI_TURNEND_EXT__`.
The watcher extension lives at `__FM_PI_EXT__`.
OMP 17.2.2 accepts both through explicit `-e` paths and uses the Pi-compatible extension API.
`bin/fm-session-start.sh` reports when the running OMP session has not loaded both required extensions.
