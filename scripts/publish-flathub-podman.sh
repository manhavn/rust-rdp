#!/usr/bin/env bash
# Interactive one-shot helper: prepare (and optionally open) a Flathub submission
# using Podman for reproducible tooling.
#
# IMPORTANT — Flathub is NOT a username/password binary upload store.
#   • First publish  = GitHub PR to flathub/flathub (branch new-pr)
#   • Later updates  = PR to flathub/io.github.manhavn.rust-rdp
# This script can: generate cargo sources, build a Flathub package tree,
# optionally push a branch and open the PR if you provide a GitHub token.
#
# Usage:
#   ./scripts/publish-flathub-podman.sh
#   ./scripts/publish-flathub-podman.sh --non-interactive   # use env vars only
#   GH_TOKEN=... ./scripts/publish-flathub-podman.sh
#
# Env (optional, skips prompts when set):
#   GH_TOKEN / GITHUB_TOKEN   GitHub PAT (repo + workflow recommended)
#   GH_USER                   GitHub username
#   GIT_URL                   Upstream git URL (default: origin https)
#   GIT_TAG                   Release tag (e.g. v0.1.0)
#   WORK_DIR                 Where to write the flathub package (default: ./flathub-out)
#   SKIP_BUILD=1             Skip podman flatpak-builder smoke test
#   OPEN_PR=1|0              Open GitHub PR automatically (default: ask)
#   MODE=first|update        first = flathub/flathub new-pr; update = app repo
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_ID="io.github.manhavn.rust-rdp"
TEMPLATE="${ROOT}/flatpak/${APP_ID}.flathub.yml.template"
NON_INTERACTIVE=0

for arg in "$@"; do
  case "$arg" in
    --non-interactive) NON_INTERACTIVE=1 ;;
    --help|-h)
      sed -n '2,35p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 1
      ;;
  esac
done

# ── helpers ──────────────────────────────────────────────────────────────────

die() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }
ok() { echo "    ✓ $*"; }

prompt() {
  # prompt VAR "Question" "default"
  local var="$1" q="$2" def="${3:-}"
  local cur="${!var:-}"
  if [[ -n "$cur" ]]; then
    return 0
  fi
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    if [[ -n "$def" ]]; then
      printf -v "$var" '%s' "$def"
      return 0
    fi
    die "Missing required env: $var"
  fi
  local ans
  if [[ -n "$def" ]]; then
    read -r -p "$q [$def]: " ans || true
    ans="${ans:-$def}"
  else
    read -r -p "$q: " ans || true
  fi
  printf -v "$var" '%s' "$ans"
}

prompt_secret() {
  local var="$1" q="$2"
  local cur="${!var:-}"
  if [[ -n "$cur" ]]; then
    return 0
  fi
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    die "Missing required secret env: $var"
  fi
  local ans
  read -r -s -p "$q: " ans || true
  echo
  printf -v "$var" '%s' "$ans"
}

prompt_yesno() {
  # sets VAR to 1 or 0
  local var="$1" q="$2" def="${3:-y}"
  local cur="${!var:-}"
  if [[ -n "$cur" ]]; then
    return 0
  fi
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    if [[ "$def" =~ ^[Yy] ]]; then printf -v "$var" '1'; else printf -v "$var" '0'; fi
    return 0
  fi
  local ans
  read -r -p "$q [y/n] (default $def): " ans || true
  ans="${ans:-$def}"
  if [[ "$ans" =~ ^[Yy] ]]; then printf -v "$var" '1'; else printf -v "$var" '0'; fi
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

default_git_url() {
  local u
  u="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
  if [[ -z "$u" ]]; then
    echo "https://github.com/manhavn/rust-rdp.git"
    return
  fi
  # normalize git@github.com:user/repo.git → https
  if [[ "$u" =~ ^git@github.com:(.+)$ ]]; then
    echo "https://github.com/${BASH_REMATCH[1]}"
  elif [[ "$u" =~ ^ssh://git@github.com/(.+)$ ]]; then
    echo "https://github.com/${BASH_REMATCH[1]}"
  else
    echo "$u"
  fi
}

# ── banner ───────────────────────────────────────────────────────────────────

cat <<'EOF'
╔══════════════════════════════════════════════════════════════╗
║  Rust RDP VNC → Flathub helper (Podman)                      ║
╠══════════════════════════════════════════════════════════════╣
║  Flathub does NOT accept store login + binary upload.        ║
║  This wizard prepares sources + package and can open a       ║
║  GitHub PR with your token. Reviewers still must approve.    ║
╚══════════════════════════════════════════════════════════════╝
EOF

need_cmd podman
need_cmd git

# ── collect inputs ───────────────────────────────────────────────────────────

GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
GH_USER="${GH_USER:-}"
GIT_URL="${GIT_URL:-}"
GIT_TAG="${GIT_TAG:-}"
WORK_DIR="${WORK_DIR:-}"
SKIP_BUILD="${SKIP_BUILD:-}"
OPEN_PR="${OPEN_PR:-}"
MODE="${MODE:-}"

prompt GIT_URL "Git HTTPS URL of this project" "$(default_git_url)"
prompt GIT_TAG "Release git tag to publish (must exist on GitHub)" "v0.1.0"
prompt WORK_DIR "Output directory for Flathub package tree" "${ROOT}/flathub-out"
prompt MODE "Submit mode: first (new app PR) or update (app repo PR)" "first"

if [[ "$MODE" != "first" && "$MODE" != "update" ]]; then
  die "MODE must be 'first' or 'update'"
fi

prompt_yesno DO_GEN "Generate flatpak/generated-sources.json now?" "y"
if [[ -z "${SKIP_BUILD}" ]]; then
  prompt_yesno SKIP_BUILD "Skip Podman flatpak-builder smoke test? (faster)" "y"
fi
prompt_yesno OPEN_PR "Open GitHub PR automatically with gh + token?" "n"

if [[ "${OPEN_PR}" == "1" ]]; then
  prompt GH_USER "GitHub username"
  prompt_secret GH_TOKEN "GitHub Personal Access Token (repo scope)"
  export GH_TOKEN GITHUB_TOKEN="$GH_TOKEN"
fi

# ── resolve tag commit ───────────────────────────────────────────────────────

info "Resolving tag ${GIT_TAG}…"
if ! git -C "$ROOT" rev-parse -q --verify "refs/tags/${GIT_TAG}" >/dev/null; then
  prompt_yesno CREATE_TAG "Tag ${GIT_TAG} not found locally. Create on current HEAD and push?" "n"
  if [[ "${CREATE_TAG:-0}" == "1" ]]; then
    git -C "$ROOT" tag "${GIT_TAG}"
    info "Pushing tag ${GIT_TAG}…"
    git -C "$ROOT" push origin "${GIT_TAG}" || die "Failed to push tag — push manually then re-run"
  else
    die "Tag ${GIT_TAG} missing. Create & push it, then re-run."
  fi
fi

GIT_COMMIT="$(git -C "$ROOT" rev-list -n 1 "${GIT_TAG}")"
ok "commit ${GIT_COMMIT}"

# ── Podman image with tools ──────────────────────────────────────────────────
# venv on a volume stores absolute symlinks to /usr/bin/python3. A bare
# ubuntu:24.04 container does NOT have python3 until apt-install — so we bake
# tools into a local image once, then reuse it.

TOOLS_IMAGE="${TOOLS_IMAGE:-localhost/rust-rdp-flathub-tools:latest}"
CACHE_VOL="rust-rdp-flathub-cache"

info "Ensuring Podman tools image (${TOOLS_IMAGE})…"
if ! podman image exists "${TOOLS_IMAGE}" 2>/dev/null; then
  info "Building tools image (one-time, ~1–2 min)…"
  podman build -t "${TOOLS_IMAGE}" -f - <<'EOF'
FROM docker.io/library/ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      git python3 python3-pip python3-venv python3-full \
      curl ca-certificates build-essential pkg-config \
 && rm -rf /var/lib/apt/lists/* \
 && python3 --version
EOF
  ok "tools image built"
else
  ok "tools image already present"
fi

info "Ensuring Podman cache volume ${CACHE_VOL}…"
podman volume exists "${CACHE_VOL}" 2>/dev/null || podman volume create "${CACHE_VOL}" >/dev/null

run_in_podman() {
  podman run --rm -i \
    -v "${ROOT}:/src:Z" \
    -v "${CACHE_VOL}:/cache:Z" \
    -w /src \
    -e DEBIAN_FRONTEND=noninteractive \
    "${TOOLS_IMAGE}" \
    bash -lc "$*"
}

# Shared setup: repair venv if broken, ensure flatpak-builder-tools clone.
PODMAN_SETUP='
  set -euo pipefail
  export PATH="/cache/bin:/cache/venv/bin:${PATH:-/usr/bin}"

  ensure_python() {
    # Generator deps: tomlkit (required by current flatpak-cargo-generator), aiohttp
    if /cache/venv/bin/python3 -c "import tomlkit, aiohttp" 2>/dev/null; then
      return 0
    fi
    echo "Creating / repairing Python venv on cache volume..."
    rm -rf /cache/venv
    python3 -m venv /cache/venv
    /cache/venv/bin/python3 -m pip install -U pip -q
    /cache/venv/bin/python3 -m pip install -q \
      "tomlkit>=0.12" "aiohttp>=3.8" "toml>=0.10"
    mkdir -p /cache/bin
    ln -sfn /cache/venv/bin/python3 /cache/bin/python3
    ln -sfn /cache/venv/bin/python3 /cache/bin/python
    /cache/venv/bin/python3 -c "import tomlkit, aiohttp; print(\"python-ok\")"
  }

  ensure_tools_repo() {
    if [[ ! -f /cache/flatpak-builder-tools/cargo/flatpak-cargo-generator.py ]]; then
      rm -rf /cache/flatpak-builder-tools
      git clone --depth 1 https://github.com/flatpak/flatpak-builder-tools.git \
        /cache/flatpak-builder-tools
    fi
  }

  ensure_python
  ensure_tools_repo
'

info "Preparing Python + flatpak-builder-tools inside Podman…"
run_in_podman "${PODMAN_SETUP}
  echo tools-ready
"
ok "Podman tooling ready"

# ── generate cargo sources ───────────────────────────────────────────────────

if [[ "${DO_GEN}" == "1" ]]; then
  info "Generating flatpak/generated-sources.json (can take several minutes)…"
  run_in_podman "${PODMAN_SETUP}
    /cache/venv/bin/python3 \
      /cache/flatpak-builder-tools/cargo/flatpak-cargo-generator.py \
      /src/Cargo.lock \
      -o /src/flatpak/generated-sources.json
    ls -lh /src/flatpak/generated-sources.json
  "
  ok "generated-sources.json"
else
  [[ -f "${ROOT}/flatpak/generated-sources.json" ]] \
    || die "flatpak/generated-sources.json missing — re-run with generate = y"
  ok "using existing generated-sources.json"
fi

# ── assemble Flathub package (TOPLEVEL only — bot: "Files not in toplevel") ─

PKG_DIR="${WORK_DIR%/}"
info "Writing Flathub package (toplevel layout) → ${PKG_DIR}"
rm -rf "${PKG_DIR}"
mkdir -p "${PKG_DIR}"

[[ -f "$TEMPLATE" ]] || die "Missing template: $TEMPLATE"

sed \
  -e "s|__GIT_URL__|${GIT_URL}|g" \
  -e "s|__GIT_TAG__|${GIT_TAG}|g" \
  -e "s|__GIT_COMMIT__|${GIT_COMMIT}|g" \
  "$TEMPLATE" > "${PKG_DIR}/${APP_ID}.yml"

cp -a "${ROOT}/flatpak/${APP_ID}.desktop" "${PKG_DIR}/"
cp -a "${ROOT}/flatpak/${APP_ID}.metainfo.xml" "${PKG_DIR}/"
cp -a "${ROOT}/flatpak/generated-sources.json" "${PKG_DIR}/"
cp -a "${ROOT}/desktop/assets/icon.png" "${PKG_DIR}/${APP_ID}.png"
printf '%s\n' '{ "only-arches": ["x86_64"] }' > "${PKG_DIR}/flathub.json"

cat > "${PKG_DIR}/README-SUBMIT.md" <<EOF
# Flathub package for ${APP_ID}

- Tag: ${GIT_TAG}
- Commit: ${GIT_COMMIT}
- Upstream: ${GIT_URL}

## First submission
1. Fork flathub/flathub (uncheck "master only")
2. git clone --branch=new-pr https://github.com/YOU/flathub.git && cd flathub
3. git checkout -b add-app
4. Copy *files* to repo ROOT (not a subfolder):  cp -a ${PKG_DIR}/* .
5. PR against base **new-pr** with filled checklist + video

## Update
Clone flathub/${APP_ID} and replace files.
EOF

ok "package tree ready (toplevel)"
ls -la "${PKG_DIR}"

# ── optional smoke build ─────────────────────────────────────────────────────

if [[ "${SKIP_BUILD}" != "1" ]]; then
  info "Smoke-testing with flatpak-builder in Podman (long)…"
  run_in_podman '
    set -e
    apt-get update -qq
    apt-get install -y -qq flatpak flatpak-builder ostree elfutils 2>/dev/null | tail -3
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
    # Runtimes are huge; only attempt if user wants full build
    echo "NOTE: Full runtime install inside container is multi-GB."
    echo "Prefer host: ./scripts/publish-flatpak.sh for local install tests."
  ' || true
  ok "skipped full runtime install in container (use host script to test run)"
fi

# ── optional GitHub PR ───────────────────────────────────────────────────────

if [[ "${OPEN_PR}" == "1" ]]; then
  need_cmd curl
  if ! command -v gh >/dev/null 2>&1; then
    info "Installing gh CLI via Podman is awkward; checking host gh…"
    die "Install GitHub CLI: https://cli.github.com/  (sudo apt install gh) then re-run with OPEN_PR=1"
  fi

  echo "${GH_TOKEN}" | gh auth login --with-token 2>/dev/null || true

  BRANCH="rust-rdp-${GIT_TAG//\//-}-$(date +%Y%m%d%H%M)"
  TMP_GH="$(mktemp -d)"
  cleanup() { rm -rf "${TMP_GH}"; }
  trap cleanup EXIT

  if [[ "$MODE" == "first" ]]; then
    info "Preparing first-app PR against flathub/flathub (new-pr)…"
    # User must already have a fork of flathub/flathub
    FORK_URL="https://github.com/${GH_USER}/flathub.git"
    info "Cloning your flathub fork: ${FORK_URL}"
    if ! git clone --depth 1 -b new-pr "${FORK_URL}" "${TMP_GH}/flathub" 2>/dev/null; then
      info "Branch new-pr missing — cloning default and creating new-pr…"
      git clone --depth 1 "${FORK_URL}" "${TMP_GH}/flathub" \
        || die "Cannot clone ${FORK_URL}. Fork https://github.com/flathub/flathub first."
      (
        cd "${TMP_GH}/flathub"
        git checkout -b new-pr
      )
    fi
    # Files must be at repository ROOT (not APP_ID/ subfolder)
    (
      cd "${TMP_GH}/flathub"
      # drop any previous nested layout
      rm -rf "${APP_ID}"
      cp -a "${PKG_DIR}/." .
      rm -f README-SUBMIT.md
      git config user.email "${GH_USER}@users.noreply.github.com"
      git config user.name "${GH_USER}"
      git add "${APP_ID}.yml" "${APP_ID}.desktop" "${APP_ID}.metainfo.xml" \
        "${APP_ID}.png" generated-sources.json flathub.json 2>/dev/null || git add -A
      git commit -m "Add ${APP_ID} (${GIT_TAG})"
      git push -u origin "HEAD:refs/heads/${BRANCH}"
      gh pr create \
        --repo flathub/flathub \
        --base new-pr \
        --head "${GH_USER}:${BRANCH}" \
        --title "Add ${APP_ID}" \
        --body "Add **${APP_ID}** (Rust RDP VNC) from ${GIT_URL} tag \`${GIT_TAG}\` (\`${GIT_COMMIT}\`).

Please review metainfo, permissions, and build."
    )
    ok "PR opened (check GitHub)"
  else
    info "Preparing update PR against flathub/${APP_ID}…"
    APP_FORK="https://github.com/${GH_USER}/${APP_ID}.git"
    # Prefer official repo if user has write access
    if gh repo view "flathub/${APP_ID}" >/dev/null 2>&1; then
      git clone --depth 1 "https://github.com/flathub/${APP_ID}.git" "${TMP_GH}/app" \
        || die "Cannot clone flathub/${APP_ID}"
      (
        cd "${TMP_GH}/app"
        git checkout -b "${BRANCH}"
      )
      # Push may need fork if no write access
      PUSH_REMOTE="https://x-access-token:${GH_TOKEN}@github.com/flathub/${APP_ID}.git"
      USE_FORK=0
    else
      die "Repo flathub/${APP_ID} not found — app not on Flathub yet; use MODE=first"
    fi
    rsync -a --delete \
      --exclude .git \
      "${PKG_DIR}/" "${TMP_GH}/app/"
    (
      cd "${TMP_GH}/app"
      git config user.email "${GH_USER}@users.noreply.github.com"
      git config user.name "${GH_USER}"
      git add -A
      git commit -m "Update ${APP_ID} to ${GIT_TAG}" || die "Nothing to commit?"
      # Try push to fork first (safer)
      if git remote get-url origin | grep -q "flathub/${APP_ID}"; then
        # Create fork if needed and push
        gh repo fork "flathub/${APP_ID}" --clone=false 2>/dev/null || true
        git remote remove fork 2>/dev/null || true
        git remote add fork "https://x-access-token:${GH_TOKEN}@github.com/${GH_USER}/${APP_ID}.git"
        git push -u fork "HEAD:${BRANCH}"
        gh pr create \
          --repo "flathub/${APP_ID}" \
          --head "${GH_USER}:${BRANCH}" \
          --title "Update to ${GIT_TAG}" \
          --body "Update to upstream \`${GIT_TAG}\` (\`${GIT_COMMIT}\`)."
      fi
    )
    ok "Update PR flow finished"
  fi
fi

# ── summary ──────────────────────────────────────────────────────────────────

cat <<EOF

╔══════════════════════════════════════════════════════════════╗
║  Done                                                        ║
╚══════════════════════════════════════════════════════════════╝

Package directory:
  ${PKG_DIR}

Contents:
  ${APP_ID}.yml          (git tag ${GIT_TAG} @ ${GIT_COMMIT})
  generated-sources.json
  desktop + metainfo + icons

Next steps if you did NOT open a PR:
  1) Ensure tag ${GIT_TAG} is on GitHub:  git push origin ${GIT_TAG}
  2) First app:
       - Fork https://github.com/flathub/flathub
       - Branch new-pr, copy ${PKG_DIR} → io.github.manhavn.rust-rdp/
       - Open PR to flathub/flathub
  3) Or re-run with OPEN_PR=1 and GH_TOKEN after forking flathub.

Docs: flatpak/README.vi.md
Local test (host): ./scripts/publish-flatpak.sh

EOF
