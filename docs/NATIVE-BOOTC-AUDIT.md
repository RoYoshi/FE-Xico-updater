# Native FE-XicoOS updater audit — Phase A

Audited 2026-10-26, before implementation. Application base:
`4cd979ae57a1611d767ec813f866725873a1a80a`; OS base:
`682e76e6bdb9be0b7b697c8b0f9cf6a926ea0474`. Both repositories were accessible.

## Existing working mechanisms (source evidence, not runtime acceptance)

The FE-Xico frontend, colors, saved preferences, keyboard/gamepad integration,
console model, OS-release parsing and configurable commands are present.
`rollbackImage` guards concurrent commands; updates use asynchronous QProcess.
The OS has manually started systemd oneshots, shared flock exclusion, no apply/reboot
flags, and an exact-match legacy config migration with a backup. No new Polkit
rule or passwordless root grant is necessary: systemd's normal authorization applies.
Run 40331602869 passed build, image smoke checks and forced optional-build failure.
It is not evidence of interactive GUI, authentication or deployment correctness.

## Findings at the audited bases

| Severity | Location | Finding / reproduction |
| --- | --- | --- |
| High | `src/components/console/console.cpp:59-109` | Arguments are joined and executed by `sh -c`. Shell metacharacters change meaning; quoted filenames are broken. Feed a semicolon as a literal argument in a process test. |
| High | Same, lines 91-100 | Optional callbacks invoked unconditionally. Crash emits error and finished; completion can happen twice. ExitStatus ignored. Final unterminated output is dropped. Test nonexistent program, SIGSEGV, empty callbacks, partial output. |
| High | `src/pages/system_update/system_update.cpp:49-119` | No busy guard; callback precedes state changes; zero exit always means success/staged. Mock zero exit without result, no-op, failure and duplicate requests. |
| High | `src/pages/system_update/SystemUpdate.qml:91-118,255-285` | No-op claims new deployment and updates to user software; shared success also labels rollback as upgrade. |
| High | OS `system_files/usr/libexec/fe-xicoos-updater-helper:14-18` and `fe-xicoos-{upgrade,rollback}.service` | Service condition may skip and return success. No bootc postcondition verification or fresh invocation result. Journal access/unsupported options are not reported reliably. |
| High / recovery | OS `fe-xicoos-rollback.service:8` | Direct rollback discards pending staged entry and can toggle already queued rollback. Must guard before invoking. No evidence of explicit unpin/delete in current code. |
| Medium | `src/main.cpp:129-141` | Context properties installed after QML creation; startup bindings can fail. Offscreen engine load must exercise all pages. |
| Medium | `src/pages/rebase_helper/rebase_helper.cpp:74-131`; `FCSystemInfo.qml` | uBlue JSON and Bazzite NVIDIA detection used for identity and driver recommendations. Not valid on Fedora-native FE-XicoOS. |
| Medium | `src/resources/config.ini:20-24` | Distributed defaults still call uupd and Bazzite rollback. |
| Medium | `src/components/kConfig/k_config.cpp:120-164` | XDG_CONFIG_DIRS can supply command config if trusted locations missing. Empty path reaches KConfig default discovery. Fail closed instead. |
| Medium | `src/utils.cpp:138-143`; `src/pages/Main.qml:477-497` | Reboot blocks UI, always returns failure, and schedules a failure message irrespective of command result. |
| Medium | `src/pages/Main.qml` controller confirm actions | Calling `triggered()` bypasses enabled guards; backend guards are needed too. |
| Medium | `src/components/console/ConsoleView.qml` | Auto-detected rich text may interpret command output; use plain text. Unbounded history risks responsiveness. |

## Missing evidence / tests

Root CMake has tests commented out. Existing sync-workflow tests are unrelated to
transactions. Need Qt process/callback tests, mocked update/rollback and malformed
result tests, headless QML loading (including lazily loaded pages), missing config,
Polkit denial/missing agent, concurrent requests, journal teardown, worker pre/post
conditions, pending rollback/staged/pinned fixtures and optional-build failure tests.
Real Plasma/Wayland, SDL controller input, Polkit dialogs and bootc lifecycle require
an isolated Fedora VM. This audit makes no claim those already work.

## Implementation contract

Keep the existing frontend and upstream-sync workflow. Use argument-list launches,
one completion per process, explicit outcome versus reboot-required state, and a
versioned result protocol. Systemd workers validate bootc v1 status under one shared
lock and write root-owned invocation-correlated results. Refuse staged replacement,
rollback toggling, incompatible deployments and implicit image switches. Keep
Flatpak maintenance separate; this change does not implement Flatpak updating.

References: https://bootc.dev/bootc/bootc-api.7.html,
https://bootc.dev/bootc/man/bootc-status.8.html,
https://bootc.dev/bootc/man/bootc-upgrade.8.html,
https://bootc.dev/bootc/man/bootc-rollback.8.html.
