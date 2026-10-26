# FE-Xico Updater: guarded Bazzite upstream synchronization

**Source of upstream updates:** [rfrench3/bazzite-updater](https://github.com/rfrench3/bazzite-updater), the fork parent.
**Destination:** [RoYoshi/FE-Xico-updater](https://github.com/RoYoshi/FE-Xico-updater), a separately branded Fedora bootc updater.

## What happens automatically

Every Monday at **12:37 UTC** (and when manually dispatched), GitHub Actions
fetches upstream `main`, locates the Git merge base, and compares incoming
files with the fork's existing changes.

- Eligible **unchanged-by-FE-Xico** upstream implementation/test files are copied
  into a **draft pull request for human review**, never merged directly.
- Files that FE-Xico has changed since the common ancestor are **not touched**.
- Branding, configuration, update and rollback commands, KDE main UI,
  desktop identity, packaging, app metadata, localization domain, CI,
  and system integration paths are explicitly excluded even if they have
  not changed yet.
- Upstream **deletions are never applied automatically**.
- New files are limited to small ordinary source or test files, not scripts
  from arbitrary directories, credentials, binaries, symlinks, or submodules.
- The PR contains `docs/upstream-sync-report.md` identifying upstream
  changes that require manual porting.
- No upstream code is run in this sync workflow. The only Python executed
  is the fork's own locally maintained synchronization script and tests.

The workflow does **not** silently rebrand FE-Xico as Bazzite or revert to
Bazzite's uupd/rollback commands. The diff is **not guaranteed to compile**:
upstream may require companion changes to protected `CMakeLists.txt`, QML
or other local files. This is deliberate; review is mandatory.

## Run it manually

Open [Review upstream Bazzite Updater changes](../.github/workflows/upstream-sync.yml)
under the fork's **Actions** tab and choose **Run workflow → main**.

After a successful job, review the draft PR:
`automation/upstream-bazzite-review` into `main`.

**GitHub settings prerequisite:** Actions must be enabled for this fork and
the repository must permit GitHub Actions to create pull requests.
The workflow requests scoped `contents: write` and `pull-requests: write`.
If your repository/org disallows PR creation by Actions, enable that
permission or the job will fail **without modifying main**.

## Review before merge

1. Read the PR's upstream sync report and confirm all FE-Xico-specific paths
   are held back.
2. Inspect new files and verify licenses and software supply-chain safety.
3. Manually port upstream changes to customized files only where appropriate,
   retaining FE-Xico OS identity, bootc commands and transaction behavior.
4. Compile, launch and verify the GUI and keyboard/controller navigation.
5. Test authorized `bootc upgrade` and `bootc rollback` against a disposable
   Fedora 44 FE-XicoOS image or VM; inspect actual deployments, not exit status
   alone. Confirm the updater doesn't silently reboot.
6. After merging the updater fork's PR, update the **pinned**
   `updater/FE-Xico-Updater` Git submodule in the **separate**
   `RoYoshi/FE-Xico` OS repository, through another reviewed source change
   and successful image CI.
7. Only publish a new signed FE-XicoOS testing image through its existing
   manual registry workflow. Keep the old known-good and pinned rollback images.

Nothing in this process changes the installed FE-ROYO system, a bootc image,
the GHCR testing tag, or an existing updater binary.

## Current limitation

Upstream's refactoring moves several pages, C++ backends and Qt component
wiring while this fork has substantial UI and command adaptations. Automated
file copying alone cannot safely reconcile that refactor. The guarded PR
will report protected files as **manual port required** rather than
guessing which Bazzite behavior should replace FE-Xico behavior.

To change that policy later, update `scripts/sync_upstream_safe.py` and its
tests in a reviewed FE-Xico commit—never by automatically trusting changes
from the upstream project.
