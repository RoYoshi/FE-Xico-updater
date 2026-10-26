# Native updater validation and VM handoff

## Scope

The application and OS changes are a pair: [updater PR #4](https://github.com/RoYoshi/FE-Xico-updater/pull/4) and [OS PR #10](https://github.com/RoYoshi/FE-Xico/pull/10). Both remain drafts. Main, the upstream synchronization workflow and release/publication settings are unchanged.

The OS continues fetching updater **main**. Until the application change is accepted, the new OS runtime gate can reject the old binary (which lacks `--qml-smoke-test`) and safely omit it. An OS PR build alone therefore does not validate the candidate application/backend pair. Use both candidate revisions in a disposable VM; do not point the current PC at either branch.

## Reproducible commands

Fedora 44 dependencies and exact invocation are maintained in `.github/workflows/native-bootc-tests.yml`:

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -D_USE_XDG_CONFIG=ON -D_INCLUDE_SUBMODULES=ON -DBUILD_TESTING=ON
cmake --build build --parallel 4
ctest --test-dir build --output-on-failure
```

In that disposable container, after installation:

```sh
cmake --install build
XDG_CURRENT_DESKTOP=KDE QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QT_QUICK_CONTROLS_STYLE=org.kde.desktop dbus-run-session -- timeout 30 /usr/bin/fe-xico-updater --qml-smoke-test
```

The smoke mode loads six pages, verifies scene attachment and fails on QML errors. The exact transient Kirigami PageRow "Created graphical object was not placed in the graphics scene" diagnostic is exempt because PageRow creates under a QtObject before insertion; actual attachment is separately checked. Container portal/FUSE diagnostics do not imply a functioning desktop session. RSS network fetching and all update/authentication operations are disabled in smoke mode. The workflow repeats loading with system configuration removed and an untrusted XDG override.

OS fixture tests, from the OS checkout:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
bash -n system_files/usr/libexec/fe-xicoos-updater-helper
bash -n system_files/usr/libexec/fe-xicoos-updater-config-migrate
bash -n build_files/build-optional-updater.sh
```

The real-systemd suite is restricted to ephemeral GitHub runners, requires explicit CI opt-in and refuses to replace existing FE-Xico units. It substitutes a fixture executable for bootc and installs temporary units under /run. Do not set its CI overrides on an installed FE-XicoOS machine. The command is in the OS `updater-native-tests.yml` workflow.

## Actual results

- Local OS fixture run: 30 tests discovered, 24 passed and 6 systemd tests skipped because this workspace has no systemd VM.
- OS revision `519fec8136bef965de7859642f510efb669f4b59`: [run 40380111904](https://github.com/RoYoshi/FE-Xico/actions/runs/40380111904), **30 passed**, including actual systemd units with mocked bootc; shell syntax passed.
- Fedora native compilation and all 3 CTest targets passed at `f2d1424275ef7f10c3fd732568c4020ebc733c99`. That run correctly failed the QML gate on the packaged Kirigami MessageDialog enum error; it is not a passing GUI result. The attempted cache workaround was removed.
- Application code revision `36dd0ff2e902ca46f8ce8c6b5f9ff14f477e948f`: [run 40380620374](https://github.com/RoYoshi/FE-Xico-updater/actions/runs/40380620374), **CMake compilation passed; all 3 CTest targets passed; all six QML pages loaded and attached successfully; missing-config/untrusted-XDG QML run passed**. The final About component uses FormCards and a standard Qt license dialog, without changing system KDE packages or disabling caches.
- The separate full OS image workflow [40380111911](https://github.com/RoYoshi/FE-Xico/actions/runs/40380111911) was still running at handoff. Its result is not included in the passing claims above; it fetches updater main, not the candidate. The prior supplied run 40331602869 remains evidence for the original build integration only.

Tests cover argument preservation, crash/start/nonzero errors, optional/exactly-once callbacks, final output, asynchronous heartbeat, bounded logs, busy rejection, staged/no-op/rollback outcomes, invalid/missing/duplicate/spoofed results, config discovery, native status validation, target/pin checks, pending-deployment protection, authorization denial, lock contention, monitor disconnect, missing executable, config migration, and optional builder forced/dependency-failure cleanup.

## Remaining acceptance gates

There is no real graphical Plasma session or booted Fedora 44 VM in this workspace. Offscreen loading is not visual QA or proof of Polkit/controller/Wayland behavior. Actual bootc mutations and reboots were never invoked. NVIDIA RTX 4060 behavior and the user's pinned recovery deployment are untested and untouched. RPM package builds are not validated by the source CMake build.

Before real-machine consideration, take snapshots of a disposable Fedora 44 bootc VM and verify:

1. Both candidate revisions installed together; OS identity, all pages, dialog text/wrapping and logs visible under Plasma Login Manager/Wayland.
2. Keyboard/mouse/controller navigation, repeated button presses and navigation while a slow operation runs.
3. Desktop Polkit approval, cancellation and missing-agent behavior; no false success or indefinitely stuck UI.
4. Real image metadata check, no-op and staged upgrade, user-requested reboot, subsequent booted identity, rollback and another user-requested reboot.
5. Recovery pin identities unchanged throughout; staged rollback refusal, already-queued rollback idempotency, no rollback available, incompatible/overlaid hosts.
6. Network/disk failures, service timeout, monitor disconnect and a fresh status read after reopening. Avoid external administrative deployment commands concurrently.
7. Optional updater omission on compilation/runtime failure with useful build logs, and inclusion of the candidate pair when all checks pass.

Composefs mutations are deliberately refused. Flatpaks remain separately managed. No production or real-machine readiness is claimed.
