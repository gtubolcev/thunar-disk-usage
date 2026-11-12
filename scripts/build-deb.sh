#!/usr/bin/env bash
# Build the .deb for the running Ubuntu or Debian release.
#
#   scripts/build-deb.sh [out-dir]
#
# The version gets the codename, so that the packages of different releases
# have different names: 0.1.0~resolute.
#
# Works in CI (as root in an ubuntu or debian container) and locally (SUDO
# is picked automatically when not root).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$(realpath -m "${1:-$ROOT/out}")
WORK=${WORK:-$ROOT/_build}/deb

if [ "$(id -u)" -ne 0 ]; then SUDO=${SUDO-sudo}; else SUDO=${SUDO-}; fi
export DEBFULLNAME=${DEBFULLNAME:-"thunar-disk-usage CI"}
export DEBEMAIL=${DEBEMAIL:-"noreply@users.noreply.github.com"}
. /etc/os-release

rm -rf "$WORK"
mkdir -p "$OUT"
"$ROOT/scripts/source.sh" "$WORK/src"
cd "$WORK/src"

VERSION="$(dpkg-parsechangelog -S Version)~$VERSION_CODENAME"
dch --newversion "$VERSION" --force-bad-version --distribution "$VERSION_CODENAME" \
  --force-distribution "Build for $PRETTY_NAME."

$SUDO mk-build-deps --install --remove \
  --tool 'apt-get -y --no-install-recommends -o Debug::pkgProblemResolver=yes' \
  debian/control

dpkg-buildpackage -us -uc -b -j"$(nproc)"

cd ..
find . -maxdepth 1 -name '*.deb' ! -name '*-dbgsym_*' -exec cp -v {} "$OUT"/ \;
