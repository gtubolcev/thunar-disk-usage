#!/usr/bin/env bash
# Build the Arch Linux package from arch/PKGBUILD.
#
#   scripts/build-arch.sh [out-dir]
#
# Meant for CI, as root in an archlinux container: installs base-devel and
# builds as an unprivileged user, since makepkg refuses to run as root.
# Locally (not root) it just runs makepkg -s.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$(realpath -m "${1:-$ROOT/out}")
WORK=${WORK:-$ROOT/_build}/arch

rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"
cp "$ROOT"/arch/* "$WORK"/
"$ROOT/scripts/source.sh" "$WORK/thunar-disk-usage"
tar -C "$WORK" -czf "$WORK/thunar-disk-usage.tar.gz" thunar-disk-usage
rm -rf "$WORK/thunar-disk-usage"

if [ "$(id -u)" -eq 0 ]; then
  pacman -Syu --noconfirm --needed base-devel git
  id builder >/dev/null 2>&1 || useradd -m builder
  echo 'builder ALL=(ALL) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/builder
  chown -R builder "$WORK"
  su builder -c "cd '$WORK' && makepkg -s --noconfirm"
else
  (cd "$WORK" && makepkg -s --noconfirm)
fi

find "$WORK" -maxdepth 1 -name '*.pkg.tar.zst' ! -name '*-debug-*' -exec cp -v {} "$OUT"/ \;
