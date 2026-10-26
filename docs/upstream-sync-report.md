# FE-Xico-Updater upstream sync review

**This is a proposal, not an automatic merge.** No FE-Xico-specific
configurations, UI, branding, packaging or update commands were overwritten.

- Fork base: `4cd979ae57a1611d767ec813f866725873a1a80a`
- Upstream: `rfrench3/bazzite-updater@4bc2a6dd1bc440bbfacd46f698475b5c57c59fc8`
- Common ancestor: `d8dbb25aa7966ffb548707048005620090323fd0`
- Files safely copied into this proposal: **23**
- Paths withheld for manual review: **42**

## Proposed upstream files (must pass application and CI review)

- `cmake/UpdateTranslations.cmake`
- `src/components/AppDialogManager.qml`
- `src/components/AppPage.qml`
- `src/components/AsyncLoader.qml`
- `src/components/PageContentLayout.qml`
- `src/components/customFormcards/FormCardCollapsible.qml`
- `src/components/customFormcards/FormDelegateCollapsible.qml`
- `src/components/customFormcards/FormDelegateSeparatorFixed.qml`
- `src/components/data/data.cpp`
- `src/components/data/data.h`
- `tests/failure/brew.txt`
- `tests/failure/flatpak-user.txt`
- `tests/failure/flatpak.txt`
- `tests/failure/system.txt`
- `tests/success/brew.txt`
- `tests/success/flatpak-user.txt`
- `tests/success/flatpak.txt`
- `tests/success/system.txt`
- `tests/uupd-failure.sh`
- `tests/uupd-module-fail.txt`
- `tests/uupd-success-slow.sh`
- `tests/uupd-success.sh`
- `tests/uupd-success.txt`

## NOT applied (manual port required where relevant)

- `CMakeLists.txt` — protected customization or outside allowlist
- `README.md` — protected customization or outside allowlist
- `bazzite-updater.spec` — protected customization or outside allowlist
- `io.github.rfrench3.bazzite-updater.desktop` — protected customization or outside allowlist
- `justfile` — protected customization or outside allowlist
- `packaging/terra/bazzite-updater/bazzite-updater.spec` — protected customization or outside allowlist
- `po/bazzite-updater.pot` — protected customization or outside allowlist
- `po/fr_FR/bazzite-updater.po` — protected customization or outside allowlist
- `po/uk_UA/bazzite-updater.po` — protected customization or outside allowlist
- `src/CMakeLists.txt` — protected customization or outside allowlist
- `src/components/AppDialog.qml` — protected customization or outside allowlist
- `src/components/customFormcards/FCOsRelease.qml` — protected customization or outside allowlist
- `src/components/customFormcards/FCSystemInfo.qml` — protected customization or outside allowlist
- `src/components/kConfig/k_config.cpp` — protected customization or outside allowlist
- `src/components/kConfig/k_config.h` — protected customization or outside allowlist
- `src/main.cpp` — protected customization or outside allowlist
- `src/pages/AboutDataOS.qml` — protected customization or outside allowlist
- `src/pages/Main.qml` — protected customization or outside allowlist
- `src/pages/other_utils/OtherUtils.qml` — protected customization or outside allowlist
- `src/pages/other_utils/other_utils.cpp` — protected customization or outside allowlist
- `src/pages/other_utils/other_utils.h` — protected customization or outside allowlist
- `src/pages/rebase_helper/RebaseHelper.qml` — protected customization or outside allowlist
- `src/pages/rebase_helper/rebase_helper.cpp` — protected customization or outside allowlist
- `src/pages/rebase_helper/rebase_helper.h` — protected customization or outside allowlist
- `src/pages/rebase_page/FCSystemImage.qml` — protected customization or outside allowlist
- `src/pages/rebase_page/RebasePage.qml` — protected customization or outside allowlist
- `src/pages/rebase_page/rebase_model.cpp` — protected customization or outside allowlist
- `src/pages/rebase_page/rebase_model.h` — protected customization or outside allowlist
- `src/pages/rss_feed/FCRssDelegate.qml` — also modified by FE-Xico since fork point
- `src/pages/rss_feed/RssPage.qml` — also modified by FE-Xico since fork point
- `src/pages/settings/Settings.qml` — protected customization or outside allowlist
- `src/pages/system_update/SystemUpdate.qml` — protected customization or outside allowlist
- `src/pages/system_update/UpdateSteps.qml` — protected customization or outside allowlist
- `src/pages/system_update/system_update.cpp` — protected customization or outside allowlist
- `src/pages/system_update/system_update.h` — protected customization or outside allowlist
- `src/pages/system_update/update_steps_model.cpp` — protected customization or outside allowlist
- `src/pages/system_update/update_steps_model.h` — protected customization or outside allowlist
- `src/resources/config.ini` — protected customization or outside allowlist
- `src/resources/rebase-targets.json` — protected customization or outside allowlist
- `tests/update.sh` — upstream deletion: manual review required
- `tests/uupd_in_1.txt` — upstream deletion: manual review required
- `version.txt` — protected customization or outside allowlist

## Before merging

1. Review upstream changes for correctness, licensing and security.
2. Port useful changes from protected files manually, retaining FE-Xico branding
   and Fedora bootc service commands, controller support and config paths.
3. Update the CMake/QML wiring for any new upstream components if required.
4. Run Fedora 44 build, QML launch, update/rollback and polkit tests.
5. Only after the updater PR is merged, update the pinned submodule in
   `RoYoshi/FE-Xico` through a separate reviewed FE-XicoOS CI change.
6. Never auto-publish or rebase the installed FE-XicoOS image from this PR.

Upstream changes to modified FE-Xico files are **reported, not discarded**.
