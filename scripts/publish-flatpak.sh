#!/usr/bin/env bash
# Build / install Rust RDP VNC as Flatpak, generate Flathub cargo sources, or print
# Flathub PR instructions.
#
# Usage:
#   ./scripts/publish-flatpak.sh                 # build + install (user)
#   ./scripts/publish-flatpak.sh --build-only    # build .flatpak bundle
#   ./scripts/publish-flatpak.sh --generate-sources
#   ./scripts/publish-flatpak.sh --bundle        # export .flatpak file
#   ./scripts/publish-flatpak.sh --flathub-help   # how to open a Flathub PR
#   ./scripts/publish-flatpak.sh --uninstall
#
# Prerequisites:
#   sudo apt install flatpak flatpak-builder
#   flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
#   flatpak install --user -y flathub \
#     org.gnome.Platform//50 org.gnome.Sdk//50 \
#     org.freedesktop.Sdk.Extension.rust-stable//25.08 \
#     org.freedesktop.Sdk.Extension.llvm20//25.08
#
# Flathub (first publish) is NOT a binary upload — you open a GitHub PR.
# See --flathub-help and flatpak/README.md / flatpak/README.vi.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_ID="io.github.manhavn.rust-rdp"
MANIFEST="flatpak/${APP_ID}.yml"
BUILD_DIR="${ROOT}/.flatpak-build"
REPO_DIR="${ROOT}/.flatpak-repo"
STATE_DIR="${ROOT}/.flatpak-builder"
BUNDLE_PATH="${ROOT}/${APP_ID}.flatpak"

MODE="install" # install | build-only | generate-sources | bundle | flathub-help | uninstall

for arg in "$@"; do
  case "$arg" in
    --build-only) MODE="build-only" ;;
    --generate-sources) MODE="generate-sources" ;;
    --bundle) MODE="bundle" ;;
    --flathub-help) MODE="flathub-help" ;;
    --uninstall) MODE="uninstall" ;;
    --help|-h)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

print_flathub_help() {
  cat <<'EOF'
========== Publish to Flathub (first time) ==========

Flathub does not accept a raw binary upload. Flow:

1) Prepare a release on GitHub
   - Tag the repo, e.g. v0.1.0
   - git tag v0.1.0 && git push origin v0.1.0

2) Generate offline Cargo sources (required by Flathub)
   ./scripts/publish-flatpak.sh --generate-sources
   Or: ./scripts/publish-flathub-podman.sh  (writes flathub-out/)

3) Read submission requirements
   https://docs.flathub.org/docs/for-app-authors/submission

4) Open the submission PR — ORDER MATTERS
   Always start from upstream branch **new-pr**, then copy packaging
   files and commit. Never base a new-app PR on **master**.

   # Prefer SSH if you use an SSH key (no username/token for git):
   git clone --branch=new-pr --single-branch \
     git@github.com:flathub/flathub.git
   # or HTTPS: https://github.com/flathub/flathub.git
   cd flathub
   git checkout -b add-io.github.manhavn.rust-rdp

   # Copy package files to repo ROOT (not a subfolder)
   cp -a /path/to/flathub-out/. .
   # expect: io.github.manhavn.rust-rdp.yml, .desktop, .metainfo.xml,
   #         generated-sources.json, icon, flathub.json

   git add io.github.manhavn.rust-rdp.yml \
           io.github.manhavn.rust-rdp.desktop \
           io.github.manhavn.rust-rdp.metainfo.xml \
           io.github.manhavn.rust-rdp.png \
           generated-sources.json flathub.json
   git commit -m "Add io.github.manhavn.rust-rdp"

   # Push to YOUR fork, PR base = new-pr
   # Fork first: https://github.com/flathub/flathub/fork
   # (uncheck "Copy the master branch only")
   git remote add fork git@github.com:YOU/flathub.git   # or HTTPS
   git push -u fork HEAD
   # PR: base flathub/flathub:new-pr  ←  head YOU:add-io.github.manhavn.rust-rdp

   One-shot (SSH key — skips username/token when key works):
     GIT_AUTH=ssh OPEN_PR=1 ./scripts/publish-flathub-podman.sh

   GitHub CLI (same order — track new-pr first):
     gh auth login -h github.com -p ssh    # once
     gh repo fork --clone flathub/flathub && cd flathub
     git fetch origin new-pr && git checkout --track origin/new-pr
     git checkout -b add-io.github.manhavn.rust-rdp
     # … copy, commit, push, then:
     gh pr create --repo flathub/flathub --base new-pr \
       --title "Add io.github.manhavn.rust-rdp"

5) Manifest uses git source + offline crates (see flathub yml template):

     - type: git
       url: https://github.com/manhavn/rust-rdp.git
       tag: v0.1.0
       commit: <full commit sha of the tag>
     - generated-sources.json

6) After merge, updates go to flathub/io.github.manhavn.rust-rdp
   (not through flathub/flathub again).

Useful links:
  https://docs.flathub.org/docs/for-app-authors/submission
  https://docs.flathub.org/docs/for-app-authors/requirements
  https://github.com/flatpak/flatpak-builder-tools (cargo generator)

Local test before submitting:
  ./scripts/publish-flatpak.sh
  flatpak run io.github.manhavn.rust-rdp
=====================================================
EOF
}

ensure_flatpak() {
  if ! command -v flatpak >/dev/null 2>&1; then
    echo "flatpak not found. Install: sudo apt install flatpak flatpak-builder" >&2
    exit 1
  fi
  if ! command -v flatpak-builder >/dev/null 2>&1; then
    echo "flatpak-builder not found. Install: sudo apt install flatpak-builder" >&2
    exit 1
  fi
}

install_runtimes() {
  echo "==> Ensuring Flathub remote + SDK runtimes…"
  flatpak remote-add --if-not-exists --user flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo || true

  # Runtime versions must match the manifest (GNOME 50 → freedesktop 25.08)
  flatpak install --user -y flathub org.gnome.Platform//50 org.gnome.Sdk//50 || true
  flatpak install --user -y flathub \
    org.freedesktop.Sdk.Extension.rust-stable//25.08 \
    org.freedesktop.Sdk.Extension.llvm20//25.08 || true
}

generate_cargo_sources() {
  echo "==> Generating flatpak/generated-sources.json from Cargo.lock…"
  local gen_dir="${ROOT}/.flatpak-cargo-gen"
  local script="${gen_dir}/cargo/flatpak-cargo-generator.py"

  if [[ ! -f "$script" ]]; then
    echo "    Cloning flatpak-builder-tools (one-time)…"
    rm -rf "$gen_dir"
    git clone --depth 1 https://github.com/flatpak/flatpak-builder-tools.git "$gen_dir"
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 required" >&2
    exit 1
  fi

  # tomli may be required depending on generator version
  python3 -m pip install --user -q toml aiohttp 2>/dev/null || true

  python3 "$script" "${ROOT}/Cargo.lock" -o "${ROOT}/flatpak/generated-sources.json"
  echo "    Wrote flatpak/generated-sources.json"
  echo "    For Flathub, add it under the rust-rdp module sources list."
  echo "    Tip: commit this file only if you want offline builds in-tree (large)."
}

build_flatpak() {
  ensure_flatpak
  install_runtimes

  if [[ ! -f "$MANIFEST" ]]; then
    echo "Missing manifest: $MANIFEST" >&2
    exit 1
  fi

  echo "==> flatpak-builder (user install=${1})…"
  # shellcheck disable=SC2086
  flatpak-builder \
    --user \
    --force-clean \
    --state-dir="${STATE_DIR}" \
    --repo="${REPO_DIR}" \
    ${1:+--install} \
    "${BUILD_DIR}" \
    "${MANIFEST}"
}

case "$MODE" in
  flathub-help)
    print_flathub_help
    ;;
  generate-sources)
    generate_cargo_sources
    ;;
  uninstall)
    ensure_flatpak
    flatpak uninstall --user -y "${APP_ID}" || true
    echo "Uninstalled ${APP_ID} (user)."
    ;;
  build-only)
    build_flatpak 0
    echo "Build finished (not installed). Repo: ${REPO_DIR}"
    ;;
  bundle)
    build_flatpak 0
    echo "==> Exporting bundle ${BUNDLE_PATH}"
    flatpak build-bundle "${REPO_DIR}" "${BUNDLE_PATH}" "${APP_ID}"
    ls -lh "${BUNDLE_PATH}"
    echo "Install with: flatpak install --user ${BUNDLE_PATH}"
    ;;
  install)
    build_flatpak 1
    echo
    echo "Installed. Run with:"
    echo "  flatpak run ${APP_ID}"
    echo
    echo "For Flathub submission steps:"
    echo "  ./scripts/publish-flatpak.sh --flathub-help"
    ;;
esac
