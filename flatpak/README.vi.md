# Đóng gói Flatpak — Flathub

[English](README.md)

Thư mục này đóng gói **Rust RDP VNC** thành Flatpak và chuẩn bị nộp lên [Flathub](https://flathub.org).

| File | Vai trò |
|------|---------|
| [`io.github.manhavn.rust-rdp.yml`](io.github.manhavn.rust-rdp.yml) | Manifest Flatpak |
| [`io.github.manhavn.rust-rdp.desktop`](io.github.manhavn.rust-rdp.desktop) | Desktop entry |
| [`io.github.manhavn.rust-rdp.metainfo.xml`](io.github.manhavn.rust-rdp.metainfo.xml) | Metadata AppStream (**bắt buộc** trên Flathub) |
| `generated-sources.json` | Crate Cargo offline (**sinh ra**, mặc định không commit) |

Script (từ root repo):

| Script | Mục đích |
|--------|----------|
| [`../scripts/publish-flatpak.sh`](../scripts/publish-flatpak.sh) | Build / cài Flatpak local |
| [`../scripts/publish-flathub-podman.sh`](../scripts/publish-flathub-podman.sh) | **Chạy 1 lần (Podman)**: sinh sources, gói Flathub, tuỳ chọn mở PR GitHub |

> **Quan trọng:** Flathub **không** nhận user/pass + upload binary như Snap Store.  
> Lần đầu = **pull request GitHub** vào org Flathub.  
> Script Podman có thể chuẩn bị gói và mở PR nếu bạn nhập **GitHub token** — maintainer Flathub vẫn phải review/merge.

---

## Tổng quan

```
Máy dev                               Flathub
───────                               ───────
flatpak-builder → cài user            PR vào flathub/flathub (nhánh new-pr)
                                      → bot build
                                      → review
                                      → merge
                                      → flathub/io.github.manhavn.rust-rdp
                                      → user: flatpak install flathub io.github.manhavn.rust-rdp
```

App ID: **`io.github.manhavn.rust-rdp`** (giữ cố định sau khi publish).

---

## Chuẩn bị

### Gói hệ thống (Debian / Ubuntu)

```bash
sudo apt install flatpak flatpak-builder git python3 python3-pip
```

### Remote Flathub + runtime (khớp manifest)

Manifest dùng **GNOME 50** + **rust-stable** + **llvm20** (nhánh Freedesktop 25.08):

```bash
flatpak remote-add --if-not-exists --user flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install --user -y flathub \
  org.gnome.Platform//50 \
  org.gnome.Sdk//50 \
  org.freedesktop.Sdk.Extension.rust-stable//25.08 \
  org.freedesktop.Sdk.Extension.llvm20//25.08
```

Script sẽ cố cài các runtime này khi chạy.

---

## Chuẩn bị Flathub một lần (Podman)

Cần [Podman](https://podman.io/). Script hỏi tag, thư mục, token GitHub (tuỳ chọn):

```bash
./scripts/publish-flathub-podman.sh
```

Chạy không hỏi (env):

```bash
export GH_TOKEN=ghp_...          # chỉ khi OPEN_PR=1
export GH_USER=yourname
export GIT_TAG=v0.1.0
export MODE=first                # hoặc update
export OPEN_PR=0
export SKIP_BUILD=1
./scripts/publish-flathub-podman.sh --non-interactive
```

Kết quả: `flathub-out/io.github.manhavn.rust-rdp/` (manifest git tag + `generated-sources.json`).

---

## Build & chạy local

```bash
cd /path/to/rust-rdp

./scripts/publish-flatpak.sh
flatpak run io.github.manhavn.rust-rdp

./scripts/publish-flatpak.sh --uninstall
```

Chế độ khác:

```bash
./scripts/publish-flatpak.sh --build-only
./scripts/publish-flatpak.sh --bundle
```

### Local khác Flathub

Manifest trong repo đang dùng:

```yaml
sources:
  - type: dir
    path: ..
```

Chỉ để **dev local**. Flathub yêu cầu:

- Source từ **git tag** công khai (hoặc archive có checksum)
- Build Cargo **offline** qua `generated-sources.json`
- Không tải crate lúc build trên máy Flathub

---

## Sinh nguồn Cargo offline

```bash
./scripts/publish-flatpak.sh --generate-sources
# → flatpak/generated-sources.json (thường rất lớn; đang gitignore)
```

Script clone [flatpak-builder-tools](https://github.com/flatpak/flatpak-builder-tools) và chạy generator trên `Cargo.lock`.

Mỗi lần đổi `Cargo.lock` trước khi update Flathub: chạy lại lệnh này.

---

## Nộp Flathub lần đầu (chi tiết)

### 1. Tạo release sạch trên GitHub

```bash
git tag v0.1.0
git push origin v0.1.0
git rev-list -n 1 v0.1.0    # ghi lại full SHA
```

### 2. Sinh `generated-sources.json`

```bash
./scripts/publish-flatpak.sh --generate-sources
```

### 3. Tham gia Flathub / đọc quy định

- [Submission](https://docs.flathub.org/docs/for-app-authors/submission)  
- [Requirements](https://docs.flathub.org/docs/for-app-authors/requirements)  
- [MetaInfo](https://docs.flathub.org/docs/for-app-authors/metainfo-guidelines)

Checklist trước PR:

- [ ] `metainfo.xml` hợp lệ  
- [ ] Screenshot **HTTPS thật** (không chỉ placeholder)  
- [ ] `finish-args` tối thiểu  
- [ ] License rõ ràng  
- [ ] Build offline được  
- [ ] Desktop + icon  

### 4. Fork Flathub, mở PR app mới

**Thứ tự bắt buộc:** lấy code từ nhánh **`new-pr`** của upstream
`https://github.com/flathub/flathub` **trước**, rồi mới copy file packaging
và commit. **Không** base PR app mới trên `master`.

1. Fork [github.com/flathub/flathub](https://github.com/flathub/flathub)  
   (bỏ chọn **“Copy the master branch only”** để fork có nhánh `new-pr`)  
2. Clone **upstream** nhánh `new-pr` (nguồn chuẩn). Ưu tiên **SSH** nếu
   bạn dùng SSH key (không cần nhập username/token cho git):

```bash
# SSH (khuyến nghị khi đã có key)
git clone --branch=new-pr --single-branch \
  git@github.com:flathub/flathub.git
# hoặc HTTPS:
# git clone --branch=new-pr --single-branch \
#   https://github.com/flathub/flathub.git
cd flathub
git checkout -b add-io.github.manhavn.rust-rdp
```

3. Copy file gói vào **ROOT repo** (không tạo thư mục con app):

```text
# sau: cp -a flathub-out/. .
io.github.manhavn.rust-rdp.yml
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

4. Push lên **fork của bạn**, mở PR với base **`new-pr`**:

```bash
# SSH
git remote add fork git@github.com:YOU/flathub.git
# hoặc HTTPS: https://github.com/YOU/flathub.git
git push -u fork HEAD
# PR: base flathub/flathub:new-pr  ←  head YOU:add-io.github.manhavn.rust-rdp
```

Hoặc one-shot (SSH key — không hỏi username/token nếu key + `gh` ổn):

```bash
GIT_AUTH=ssh OPEN_PR=1 ./scripts/publish-flathub-podman.sh
# HTTPS:
# GIT_AUTH=https GH_USER=you GH_TOKEN=ghp_… OPEN_PR=1 ./scripts/publish-flathub-podman.sh
```

GitHub CLI (cùng thứ tự — checkout `new-pr` trước):

```bash
gh auth login -h github.com -p ssh   # một lần
gh repo fork --clone flathub/flathub && cd flathub
git fetch origin new-pr && git checkout --track origin/new-pr
git checkout -b add-io.github.manhavn.rust-rdp
# … copy + commit …
git push -u origin HEAD
gh pr create --repo flathub/flathub --base new-pr \
  --title "Add io.github.manhavn.rust-rdp"
```

### 5. Manifest Flathub: bỏ `type: dir`

Trong bản submit Flathub:

```yaml
sources:
  - type: git
    url: https://github.com/manhavn/rust-rdp.git
    tag: v0.1.0
    commit: THAY_BANG_FULL_SHA

  - generated-sources.json
```

Build phải **`cargo --offline`**.

### 6. Sau khi mở PR

- Base: `flathub/flathub` **`new-pr`** (không phải `master`)  
- Title ví dụ: `Add io.github.manhavn.rust-rdp`  
- Bot build app; sửa đến khi CI xanh và review pass.

### 7. Sau khi merge

- App lên Flathub (có thể trễ vài phút/giờ)  
- Bảo trì lâu dài tại **`github.com/flathub/io.github.manhavn.rust-rdp`**  
- Bản mới: tag upstream → cập nhật tag/commit + sources + metainfo → PR  

```bash
flatpak install flathub io.github.manhavn.rust-rdp
flatpak update io.github.manhavn.rust-rdp
```

---

## Giải thích `finish-args`

| Tham số | Lý do |
|---------|--------|
| `--share=network` | RDP / VNC |
| `--socket=wayland` / `fallback-x11` | GUI |
| `--device=dri` | OpenGL |
| `--share=ipc` | GUI thông thường |
| (không `--filesystem=home`) | Mở/lưu qua **FileChooser portal** (`rfd` xdg-portal) |

**Không** dùng `--filesystem=home` / `host` — linter Flathub từ chối
(`finish-args-home-filesystem-access`). Dùng portal.

---

## AppStream / metainfo

File: `io.github.manhavn.rust-rdp.metainfo.xml`

- `id` = app id  
- `launchable` trỏ đúng desktop id  
- Mỗi bản phát hành: thêm `<release version="…" date="…">`  
- Screenshot: URL HTTPS ổn định  
- Content rating OARS  

```bash
appstreamcli validate flatpak/io.github.manhavn.rust-rdp.metainfo.xml
```

---

## Cập nhật app đã có trên Flathub

1. Tag version mới trên GitHub  
2. Generate lại `generated-sources.json`  
3. Sửa repo `flathub/io.github.manhavn.rust-rdp` (tag, commit, metainfo)  
4. PR / quy trình update của Flathub  
5. Chờ build + merge  

---

## Xử lý lỗi

| Vấn đề | Gợi ý |
|--------|--------|
| Thiếu runtime | Cài đúng `//50` và extension `//25.08` |
| Linter: runtime-is-eol | Nâng `runtime-version` (hiện `"50"`) |
| Linter: finish-args-home-filesystem-access | Bỏ `--filesystem=home`; dùng portal |
| Cargo cần mạng trên Flathub | Thiếu/cũ `generated-sources.json` |
| Git dep (IronRDP) offline fail | Generate lại sau khi đổi lockfile |
| Lỗi LLVM / openh264 | Giữ extension `llvm20` + `LIBCLANG_PATH` |
| Review AppStream fail | Sửa screenshot, mô tả, releases |
| Hỏi quyền | Giải thích từng dòng `finish-args` trong PR |

---

## Tài liệu chính thức

- https://docs.flathub.org/docs/for-app-authors/submission  
- https://docs.flathub.org/docs/for-app-authors/requirements  
- https://docs.flatpak.org/  
- https://github.com/flatpak/flatpak-builder-tools  

---

## Liên quan trong repo

```
flatpak/
  io.github.manhavn.rust-rdp.yml
  io.github.manhavn.rust-rdp.desktop
  io.github.manhavn.rust-rdp.metainfo.xml
  README.md
  README.vi.md              ← file này
scripts/publish-flatpak.sh
desktop/assets/icon*.png
```

```bash
./scripts/publish-flatpak.sh --flathub-help
```
