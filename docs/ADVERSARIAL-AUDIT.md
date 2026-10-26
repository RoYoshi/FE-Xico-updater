# Adversarial audit — native bootc integration

Independent second pass by the implementing engineer, 2026-10-26. This is not an independent human/security certification. Baseline findings are in [NATIVE-BOOTC-AUDIT.md](NATIVE-BOOTC-AUDIT.md). Companion OS changes: RoYoshi/FE-Xico PR #10; application: PR #4.

## Findings corrected during the second pass

- **False success after a skipped/failed unit:** the client requires a successful systemctl job and a fresh root-owned worker result. It checks invocation and retained systemd timestamps/exit fields. Actual systemd testing exposed garbage collection of completed oneshots; default empty status records are never sufficient evidence of success.
- **Protocol spoofing:** raw bootc output is prefixed by the client. Only one stdout result is accepted by the GUI; stderr, malformed/duplicate/contradictory JSON, crashes and nonzero exit all fail. The frontend settles state before its completion callback.
- **Rollback damage/toggling:** preflight refuses a staged deployment and returns an idempotent result when rollback is already queued. There are no switch, cleanup, reset, unpin or automatic reboot calls. Pinned identities and booted identity are compared after operations; a mismatch is an error with no automatic repair.
- **Console resource exhaustion and markup:** history, individual displayed lines, partial lines and service log files are bounded. Text uses plain-text rendering. The complete bootc stream remains in the service journal.
- **Unsafe configuration discovery/migration:** command settings ignore environment-controlled XDG locations. Missing configuration disables operations. Migration now scopes replacements to Commands, preserves unknown custom commands/settings, backs up legacy files and atomically replaces the configuration.
- **GUI dependency failures hidden by compilation:** tests load every page. Missing About metadata produced startsWith errors; defaults now satisfy the documented KAboutData shape. The Fedora dependency stack also exposed a Kirigami MessageDialog enum-binding failure; a local FormCard About component avoids that dependency defect while keeping metadata, credits, licenses and library information. The unsuccessful cache workaround was removed.
- **Packaging gaps:** removed installation of the unused legacy service-as-program shell helper, added test build dependencies to both RPM specs, checked ldd's own exit status in the optional runtime gate, and retained explicit optional-install fallback.

## Security boundary and residual risks

Systemd authorizes the fixed services using its existing Polkit policy. No new privilege grant or passwordless rule is installed. Workers run Python in isolated mode, accept only four fixed actions, use absolute executable paths and one root-owned shared lock. The GUI never executes shell-interpolated commands. A trusted administrator may still customize command configuration; custom commands must implement the result contract to be reported successful.

The lock coordinates these services only. An administrator directly invoking bootc/rpm-ostree outside them can race between status snapshots and mutations. Bootc has its own transaction exclusion, but this is not a multi-command lock covering external administrative tools. Avoid concurrent administrative deployment work; failures require status refresh and manual review, not automatic repair.

Postcondition checks detect unexpected pinned-state changes after an operation; they are not a replacement for validating real bootc behavior and recovery in a disposable VM. Mutation is restricted to ostreeContainer deployments. Composefs and other backends are refused pending separate validation.

Closing/killing the GUI or monitor does not cancel the system service. Logs and results are bounded, volatile under /run and not a persistent transaction database. A lost/invalid result is unverified, never success. Polling is indeterminate progress, not a fabricated percentage.

## Regression scope

FE-Xico colors, branding, update/recovery layouts, preferences, RSS, keyboard/gamepad integration and the separate upstream synchronization workflow are retained. Bazzite image probing, NVIDIA recommendations and unsupported rebase targets are removed from the active backend. Historical upstream acknowledgements, translations and an uninstalled legacy helper can still mention Bazzite; these are not runtime update dependencies. Flatpak updating is not implemented by this change and is explicitly separate in the UI.

No live PC deployment, boot configuration, recovery pin, NVIDIA configuration or FE-Xico Doctor file was changed. The drafts are unmerged; no image was published.

## Required release gate

Passing mocks and offscreen QML establishes readiness for isolated VM evaluation only. A real Fedora 44 bootc VM must verify Plasma/Wayland launch, desktop Polkit approve/cancel/missing-agent paths, mouse/keyboard/controller navigation, real metadata check, no-op and staged upgrade, reboot into the staged deployment, rollback and its reboot, pinned recovery preservation, network/disk failures and interrupted monitoring. Real-machine and production approval remain blocked on those results and independent review.
