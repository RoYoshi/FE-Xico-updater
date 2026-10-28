# FE-Xico Updater

**FE-Xico Updater** is a Qt 6 / KDE Kirigami graphical frontend for system updates and deployment recovery on [FE-Xico](https://github.com/RoYoshi/FE-Xico). It supports keyboard, mouse, touchscreen, and controller interaction.

This is a **work in progress**, adapted from [Bazzite Updater](https://github.com/rfrench3/bazzite_updater). The application is FE-Xico-branded, but it currently delegates updates and rollback to existing system utilities; it is not an independent replacement for those utilities.

![FE-Xico hat branding](io.github.royoshi.fexicoupdater.svg)

## Automatic bootc updates (FE-XicoOS)

Under **Settings → Automatic OS Updates**, check **Enable automatic OS updates** to turn on the system timer. The checkbox reads the actual `bootc-fetch-apply-updates.timer` state, rather than storing a local preference. Enabling or disabling prompts for confirmation and then the administrator password via the image-provided FE-XicoOS Polkit helper; manual updates remain available when automatic updates are off.

**Important:** The stock bootc automatic-update service can **reboot the machine without asking**, including during a game. The dialog warns before enabling it. Your tracked bootc image source does not change. The UI gracefully disables this setting on non-FE-XicoOS hosts without the helper.


- Start the configured system-update service and display live command output.
- Show command success or failure and offer reboot guidance.
- Provide a rollback interface using the system's configured rollback helper.
- Display operating-system and image information, when available.
- Support controller navigation, fullscreen operation, and KDE color integration.

## FE-Xico integration

The [FE-Xico image Containerfile](https://github.com/RoYoshi/FE-Xico/blob/main/Containerfile) builds this repository as a Git submodule and installs the resulting application into FE-Xico.

The default commands in [`src/resources/config.ini`](src/resources/config.ini) are:

```ini
[Commands]
systemUpdateCommand=./service-as-program.sh uupd-manual.service
systemRollbackCommand=bazzite-rollback-helper rollback -y
```

The `service-as-program.sh` helper starts the named systemd service and streams its journal output. `uupd-manual.service` is the GUI's default update target; the separately scheduled `uupd.service` may share the underlying system updater. A healthy graphical frontend does not by itself establish that either service can successfully upgrade the installed image.

FE-Xico's default system update workflow therefore still depends on **Universal Blue's `uupd`**. Rollback still uses the inherited `bazzite-rollback-helper`. Both may be replaced later, but these dependencies should not be removed until a tested replacement is available.

## Configuration

The image installs the application configuration under `/etc/fe-xico-updater/` by default:

- `config.ini` — update and rollback commands, and release-feed settings.
- `KAboutData_OS.json` — operating-system information displayed in the UI.
- `service-as-program.sh` — helper for running systemd service jobs.

User-interface preferences, including the reboot reminder, are stored separately in `~/.config/fe-xico-updaterrc`. Update commands are read from the system configuration, not from the user's home directory.

Leave `systemRollbackCommand` empty to hide the rollback action. Do not point the update command at an untested service; update jobs may need elevated privileges and should not be interrupted mid-deployment.

## Building

Clone with Git submodules:

```bash
git clone --recurse-submodules https://github.com/RoYoshi/FE-Xico-Updater.git
cd FE-Xico-Updater
```

This project uses CMake, Qt 6, KDE Frameworks 6, Kirigami, SDL3, and the `controllable` submodule. The developer `justfile` provides local build, run, and translation tasks. For example:

```bash
just update-submodules
just build
just run
```

Experimental Terra recipes are available through `just build-terra` and `just build-terra-44`; they have not been verified in this fork.

The FE-Xico image build compiles and installs the application directly; see its Containerfile for the currently used build flags and dependencies.

For release tooling, the RPM GitHub Actions workflow builds `fe-xico-updater.spec`. The inherited Flatpak workflow still needs a valid `.flatpak-manifest.json` before it can produce a Flatpak, and the Terra packaging recipes have not been verified in this fork.

## Status and limitations

- FE-Xico Updater currently uses `uupd` and Bazzite rollback integration.
- Update success depends on the underlying OS deployment state. In particular, local `rpm-ostree` modifications can prevent `bootc`-managed upgrades.
- Automated C++/QML tests are not yet enabled in CMake; verify update and rollback behavior on a test deployment.
- Some release, driver, and image-information views still depend on Universal Blue/Bazzite metadata.

## FE-Xico branding

The updater uses the `io.github.royoshi.fexicoupdater` application ID and FE-Xico's neon green (`#00FF00`) and magenta (`#FF00FF`). The packaged application icon is `io.github.royoshi.fexicoupdater.svg`, using the official FE-Xico hat artwork. On FE-Xico systems, the OS About page also references the FE-Xico hat icon.

## Credits and licensing

Adapted from [Bazzite Updater by Robert French and contributors](https://github.com/rfrench3/bazzite_updater). FE-Xico-specific branding and integration are maintained here. The original source copyright notices and license information are retained.

See [`LICENSES/`](LICENSES/) for the licenses covering the included code and resources. The application is generally licensed under **GPL-2.0-or-later**, with some components carrying their own notices.
