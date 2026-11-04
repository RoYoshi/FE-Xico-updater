# FE-Xico Updater

**FE-Xico Updater** is the system-maintenance utility of [FE-XicoOS](https://github.com/RoYoshi/FE-Xico): a Qt 6 / KDE Kirigami application that shows whether the system is current, checks for and prepares FE-XicoOS image updates, and explains restart and rollback in plain language. It works with keyboard, mouse, touch and game controllers.

It began as a fork of [Bazzite Updater](https://github.com/rfrench3/bazzite_updater) by Robert French and contributors (see [Credits and licensing](#credits-and-licensing)). On FE-XicoOS it no longer uses uupd or Bazzite helpers: it talks only to FE-XicoOS's own bootc services.

<img src="icons/hicolor/256x256/apps/io.github.royoshi.fexicoupdater.png" alt="FE-Xico Updater icon" width="128">

## What it shows

The dashboard derives one state from the backend's verified result and offers one main action for it:

| State | Main action |
| --- | --- |
| Status not read yet / system status read | Check for Updates |
| Checking, downloading and preparing, reading, queuing rollback | View Progress |
| Update available | Update System |
| Update ready, or rollback ready — restart to finish | Restart to Finish |
| Download kept (locked download-only deployment) | Review Deployments |
| Up to date | Check for Updates |
| Operation not completed | Review Error |

"Up to date" appears only after a check or update actually returned that result and no newer or pending deployment is shown. A failed or unverifiable operation never looks like success. Progress is indeterminate, because bootc does not report reliable percentages. The real command output is always available under **Technical Details** (F12 or the Y button).

By default the updater reads the deployment status (read-only) when it opens, so the dashboard can show the real state. Turn this off under **Settings → Updates**.

## How it works on FE-XicoOS

The commands in [`src/resources/config.ini`](src/resources/config.ini), installed by FE-XicoOS as `/etc/fe-xico-updater/config.ini`, are:

```ini
[Commands]
systemUpdateCommand=/usr/libexec/fe-xicoos-updater-helper fe-xicoos-upgrade.service
systemRollbackCommand=/usr/libexec/fe-xicoos-updater-helper fe-xicoos-rollback.service
systemCheckCommand=/usr/libexec/fe-xicoos-updater-helper fe-xicoos-check.service
systemStatusCommand=/usr/libexec/fe-xicoos-updater-helper fe-xicoos-status.service
```

Each command starts one fixed systemd service through Polkit, and the service runs bootc as root. The application itself never runs as root. Only a versioned result line (`FE_XICO_RESULT`, protocol 1) that matches the requested action and the reported deployment state counts as success. The updater:

- never restarts the computer by itself (restart always needs your confirmation);
- never switches the tracked image, selects driver editions or changes recovery pins;
- runs one operation at a time;
- refuses rollback while an update is waiting for a restart.

## Automatic OS updates

**Settings → Automatic OS Updates** shows and changes the real state of FE-XicoOS's `fe-xicoos-auto-update.timer` (not a local preference). Changes need confirmation and an administrator password. That timer checks and stages updates outside your active hours and never restarts the computer.

**Important:** the stock bootc `bootc-fetch-apply-updates.timer` can **reboot the machine without asking**, including during a game. FE-XicoOS keeps it masked, and this updater does not enable it. On systems without the FE-XicoOS helper, the setting is disabled.

## Configuration

FE-XicoOS installs the system configuration under `/etc/fe-xico-updater/`:

- `config.ini`: the commands above and the release-notes feed.
- `KAboutData_OS.json`: operating-system information for the About page.

Personal preferences (restart reminder, fullscreen, Technical Details open by default, reading status at startup) are stored in `~/.config/fe-xico-updaterrc`. Commands are only ever read from the root-owned system configuration, never from your home directory.

## Building and testing

Clone with Git submodules:

```bash
git clone --recurse-submodules https://github.com/RoYoshi/FE-Xico-Updater.git
cd FE-Xico-Updater
```

The project uses CMake, Qt 6, KDE Frameworks 6, Kirigami, SDL3 and the `controllable` submodule. The `justfile` provides local build, run and translation tasks:

```bash
just update-submodules
just build
just run
```

The pull-request CI builds on Fedora 44 and 45, runs `ctest`, and loads every page offscreen (`fe-xico-updater --qml-smoke-test`). It also saves screenshots of simulated states (`fe-xico-updater --render-previews DIR`) as a build artifact. Each image is labelled "Simulated preview", and no operation is ever run. None of this exercises a real bootc update or rollback, so verify those on a disposable test deployment.

The FE-XicoOS image build compiles this repository's `main` branch; see its Containerfile for the flags it uses. The Terra recipes and the Flatpak workflow are inherited and have not been verified in this fork.

## Status and limitations

- Update success depends on the deployment state; for example, local `rpm-ostree` modifications can prevent bootc-managed upgrades.
- The release-notes page reads the FE-XicoOS releases feed; there is no in-app changelog per image.
- Secure Boot and real-hardware update/rollback behaviour must be verified on a test deployment.

## FE-Xico branding

The updater uses the `io.github.royoshi.fexicoupdater` application ID and FE-Xico's neon green (`#00FF00`) and magenta (`#FF00FF`). The application icon is RoYoshi's FE-Xico top hat with a magenta update arrow. It is installed as raster `io.github.royoshi.fexicoupdater.png` icons at every hicolor size (16–512 px), and as the embedded window-icon fallback `src/resources/FE-XicoUpdater.png`. All of them are built from the pinned original in `branding/` by `scripts/build_icons.py`, which needs Pillow and is not part of the CMake build. On FE-XicoOS, the OS About page shows the FE-XicoOS top hat (`programLogo` in `KAboutData_OS.json`).

## Credits and licensing

Adapted from [Bazzite Updater by Robert French and contributors](https://github.com/rfrench3/bazzite_updater). FE-Xico-specific branding and integration are maintained here. The original source copyright notices and license information are retained.

See [`LICENSES/`](LICENSES/) for the licenses covering the included code and resources. The application is generally licensed under **GPL-2.0-or-later**, with some components carrying their own notices.
