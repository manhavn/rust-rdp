# Flatpak packaging — Flathub

[Tiếng Việt](README.vi.md)

This directory packages **Rust RDP VNC** as a Flatpak and prepares a submission to [Flathub](https://flathub.org).

| File | Purpose |
|------|---------|
| [`io.github.manhavn.rust-rdp.yml`](io.github.manhavn.rust-rdp.yml) | Flatpak manifest |
| [`io.github.manhavn.rust-rdp.desktop`](io.github.manhavn.rust-rdp.desktop) | Desktop entry |
| [`io.github.manhavn.rust-rdp.metainfo.xml`](io.github.manhavn.rust-rdp.metainfo.xml) | AppStream metadata (required by Flathub) |
| `generated-sources.json` | Offline Cargo crates (**generated**, not committed by default) |

Scripts (repo root):

| Script | Purpose |
|--------|---------|
| [`../scripts/publish-flatpak.sh`](../scripts/publish-flatpak.sh) | Local Flatpak build / install |
| [`../scripts/publish-flathub-podman.sh`](../scripts/publish-flathub-podman.sh) | **Interactive one-shot** (Podman): generate sources, package tree, optional GitHub PR |

> **Important:** Flathub does **not** accept username/password binary upload like Snap Store.  
> First publish = **GitHub pull request** to the Flathub org.  
> The Podman script can prepare everything and open the PR if you provide a **GitHub token** — Flathub maintainers still review/merge.

---

## Overview

```
Local development                     Flathub
─────────────────                     ───────
flatpak-builder → install user        PR to flathub/flathub (new-pr)
                                      → build bot
                                      → review
                                      → merge
                                      → flathub/io.github.manhavn.rust-rdp
                                      → users: flatpak install flathub io.github.manhavn.rust-rdp
```

App ID: **`io.github.manhavn.rust-rdp`** (must stay stable forever once published).

---

## Prerequisites

### Packages (Debian / Ubuntu)

```bash
sudo apt install flatpak flatpak-builder git python3 python3-pip
```

### Flathub remote + runtimes (match the manifest)

Manifest uses **GNOME 50** + **rust-stable** + **llvm20** (Freedesktop 25.08 line):

```bash
flatpak remote-add --if-not-exists --user flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install --user -y flathub \
  org.gnome.Platform//50 \
  org.gnome.Sdk//50 \
  org.freedesktop.Sdk.Extension.rust-stable//25.08 \
  org.freedesktop.Sdk.Extension.llvm20//25.08
```

The script installs these automatically when possible.

---

## One-shot Flathub prep (Podman)

Requires [Podman](https://podman.io/). Interactive prompts for tag, paths, and optional GitHub token:

```bash
./scripts/publish-flathub-podman.sh
```

Non-interactive example:

```bash
export GH_TOKEN=ghp_...          # optional, only if OPEN_PR=1
export GH_USER=yourname
export GIT_TAG=v0.1.0
export MODE=first                # or update
export OPEN_PR=0                 # 1 = open PR with gh
export SKIP_BUILD=1
./scripts/publish-flathub-podman.sh --non-interactive
```

Output package: `flathub-out/io.github.manhavn.rust-rdp/` (manifest with git tag + `generated-sources.json`).

---

## Local build & run

```bash
cd /path/to/rust-rdp

# Build + install for the current user
./scripts/publish-flatpak.sh

# Run
flatpak run io.github.manhavn.rust-rdp

# Uninstall
./scripts/publish-flatpak.sh --uninstall
```

Other modes:

```bash
./scripts/publish-flatpak.sh --build-only   # build into local repo only
./scripts/publish-flatpak.sh --bundle       # export io.github.manhavn.rust-rdp.flatpak
```

### Local vs Flathub-safe builds

The checked-in manifest uses:

```yaml
sources:
  - type: dir
    path: ..
```

That is **for local development only**. Flathub requires:

- Source from a public **git tag** (or archive with checksum)
- **Offline** Cargo builds via `generated-sources.json`
- No downloading crates at build time on their builders

---

## Generate offline Cargo sources

Flathub policy: reproducible offline dependency fetch.

```bash
./scripts/publish-flatpak.sh --generate-sources
# writes flatpak/generated-sources.json (often large; gitignored by default)
```

This clones [flatpak-builder-tools](https://github.com/flatpak/flatpak-builder-tools) and runs `flatpak-cargo-generator.py` on the workspace `Cargo.lock`.

Re-run whenever `Cargo.lock` changes before a Flathub update.

---

## First submission to Flathub (step by step)

### 1. Prepare a clean release on GitHub

```bash
# Ensure main is green, docs/metainfo OK
git tag v0.1.0
git push origin v0.1.0

# Note the commit SHA of the tag
git rev-list -n 1 v0.1.0
```

### 2. Generate `generated-sources.json`

```bash
./scripts/publish-flatpak.sh --generate-sources
```

### 3. Join Flathub / read requirements

- [Submission guide](https://docs.flathub.org/docs/for-app-authors/submission)  
- [Requirements](https://docs.flathub.org/docs/for-app-authors/requirements)  
- [MetaInfo guidelines](https://docs.flathub.org/docs/for-app-authors/metainfo-guidelines)

Checklist before PR:

- [ ] Valid `metainfo.xml` (AppStream)
- [ ] Real **HTTPS screenshots** (not placeholder-only)
- [ ] Minimal `finish-args` (only needed permissions)
- [ ] License clear (project + metainfo)
- [ ] App builds offline with generated sources
- [ ] Desktop file + icons (128/256/512 as needed)

### 4. Fork Flathub and open a “new app” PR

**Order matters.** Always take the tree from upstream **`new-pr`**, then copy packaging files and commit. Do **not** base a new-app PR on `master`.

1. Fork [github.com/flathub/flathub](https://github.com/flathub/flathub)  
   (uncheck **“Copy the master branch only”** so `new-pr` is available on the fork)  
2. Clone **upstream** branch `new-pr` (source of truth). Prefer **SSH**
   if you use an SSH key (no username/token for git):

```bash
# SSH (recommended when you already have a key)
git clone --branch=new-pr --single-branch \
  git@github.com:flathub/flathub.git
# or HTTPS:
# git clone --branch=new-pr --single-branch \
#   https://github.com/flathub/flathub.git
cd flathub
git checkout -b add-io.github.manhavn.rust-rdp
```

3. Copy package files to the **repository root** (not a subfolder):

```text
# after: cp -a flathub-out/. .
io.github.manhavn.rust-rdp.yml          # Flathub manifest (git source!)
io.github.manhavn.rust-rdp.metainfo.xml
io.github.manhavn.rust-rdp.desktop
io.github.manhavn.rust-rdp.png
generated-sources.json
flathub.json
```

```bash
cp -a /path/to/rust-rdp/flathub-out/. .
rm -f README-SUBMIT.md
git add io.github.manhavn.rust-rdp.yml \
        io.github.manhavn.rust-rdp.desktop \
        io.github.manhavn.rust-rdp.metainfo.xml \
        io.github.manhavn.rust-rdp.png \
        generated-sources.json flathub.json
git commit -m "Add io.github.manhavn.rust-rdp"
```

4. Push to **your fork**, open PR with base **`new-pr`**:

```bash
# SSH
git remote add fork git@github.com:YOU/flathub.git
# or HTTPS: https://github.com/YOU/flathub.git
git push -u fork HEAD
# PR: base flathub/flathub:new-pr  ←  head YOU:add-io.github.manhavn.rust-rdp
```

One-shot (SSH key — skips username/token prompts when key works):

```bash
GIT_AUTH=ssh OPEN_PR=1 ./scripts/publish-flathub-podman.sh
# HTTPS:
# GIT_AUTH=https GH_USER=you GH_TOKEN=ghp_… OPEN_PR=1 ./scripts/publish-flathub-podman.sh
```

GitHub CLI (same order — track `new-pr` first):

```bash
gh auth login -h github.com -p ssh   # once
gh repo fork --clone flathub/flathub && cd flathub
git fetch origin new-pr && git checkout --track origin/new-pr
git checkout -b add-io.github.manhavn.rust-rdp
# … copy + commit …
git push -u origin HEAD
gh pr create --repo flathub/flathub --base new-pr \
  --title "Add io.github.manhavn.rust-rdp"
```

### 5. Flathub manifest: replace `type: dir`

In the Flathub copy of `io.github.manhavn.rust-rdp.yml`, module sources should look like:

```yaml
sources:
  - type: git
    url: https://github.com/manhavn/rust-rdp.git
    tag: v0.1.0
    commit: REPLACE_WITH_FULL_SHA

  - generated-sources.json
```

Build commands must use **`cargo --offline`** (the generator sets up the cargo vendor/config layout).

### 6. After the PR

- Base must be `flathub/flathub` **`new-pr`** (not `master`)  
- Title example: `Add io.github.manhavn.rust-rdp`  
- Bot builds the app; fix CI until green  

### 7. After merge

- App appears on Flathub (may take a short time to propagate)  
- Long-term maintenance happens in **`github.com/flathub/io.github.manhavn.rust-rdp`**  
- Version updates: new tag upstream → update tag/commit + regenerate sources → PR to the app repo  

```bash
flatpak install flathub io.github.manhavn.rust-rdp
flatpak update io.github.manhavn.rust-rdp
```

---

## Permissions (`finish-args`) explained

| Argument | Reason |
|----------|--------|
| `--share=network` | RDP / VNC |
| `--socket=wayland` / `fallback-x11` | GUI |
| `--device=dri` | OpenGL / eframe |
| `--share=ipc` | Standard GUI |
| (no `--filesystem=home`) | Open/save via **FileChooser portal** (`rfd` xdg-portal) |

Do **not** use `--filesystem=home` / `host` — Flathub linter rejects them
(`finish-args-home-filesystem-access`). Prefer portals.

---

## AppStream / metainfo tips

File: `io.github.manhavn.rust-rdp.metainfo.xml`

- `id` must match app id  
- `launchable` → desktop file id  
- `releases` with version + date for each store release  
- Screenshots: **stable public HTTPS URLs** (e.g. raw.githubusercontent.com or project site)  
- OARS content rating  

Validate locally if you have `appstreamcli`:

```bash
appstreamcli validate flatpak/io.github.manhavn.rust-rdp.metainfo.xml
```

---

## Updating an existing Flathub app

1. Tag new version on GitHub (`v0.1.1`)  
2. Regenerate `generated-sources.json`  
3. In `flathub/io.github.manhavn.rust-rdp`: bump tag/commit, sources, metainfo release entry  
4. Open PR or use Flathub’s update workflow  
5. Wait for build + merge  

---

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| Missing runtime / extension | Install exact `//50` and `//25.08` refs above |
| Linter: runtime-is-eol | Bump `runtime-version` (currently `"50"`) |
| Linter: finish-args-home-filesystem-access | Remove `--filesystem=home`; use portals |
| Cargo network during Flathub build | Missing or stale `generated-sources.json` |
| Git dependencies (IronRDP) fail offline | Re-run generator after lockfile change; ensure git sources are in the generated file |
| LLVM / openh264 / bindgen errors | Keep `llvm20` extension + `LIBCLANG_PATH` in manifest |
| AppStream review fails | Fix screenshots, description, releases |
| Permission questions | Justify each `finish-args` line in the PR |

---

## Official documentation

- https://docs.flathub.org/docs/for-app-authors/submission  
- https://docs.flathub.org/docs/for-app-authors/requirements  
- https://docs.flatpak.org/en/latest/  
- https://github.com/flatpak/flatpak-builder-tools (Cargo generator)  

---

## Related paths

```
flatpak/
  io.github.manhavn.rust-rdp.yml
  io.github.manhavn.rust-rdp.desktop
  io.github.manhavn.rust-rdp.metainfo.xml
  README.md                 ← this file
  README.vi.md
scripts/publish-flatpak.sh
desktop/assets/icon*.png
```

Quick help dump:

```bash
./scripts/publish-flatpak.sh --flathub-help
```
