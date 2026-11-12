#!/usr/bin/env bash
# Build a signed source package and upload it to a Launchpad PPA, which then
# builds the .debs for amd64 and the other arches.
#
#   scripts/upload-ppa.sh [codename]
#
# codename defaults to the running release. The version is that of
# debian/changelog plus the codename and an upload number
# (0.1.0~resolute~ppa1). RELEASE=v0.1.0 (the tag) must match
# debian/changelog. PPA=... overrides the target (ppa:gtubolcev/xfce-patches,
# where the plugin was published before it got a repository of its own).
#
# Needs a GPG key known to Launchpad; SIGN_KEY=... picks the key (else the
# one of DEBEMAIL); NO_UPLOAD=1 only builds the source package (unsigned)
# into _build/ppa/.
set -euo pipefail

. /etc/os-release
DIST=${1:-$VERSION_CODENAME}
PPA=${PPA:-ppa:gtubolcev/xfce-patches}
PPA_ARCHIVE=$(sed -E 's|^ppa:([^/]+)/(.+)$|~\1/+archive/ubuntu/\2|' <<< "$PPA")
ROOT=$(cd "$(dirname "$0")/.." && pwd)
WORK=$ROOT/_build/ppa/$DIST
export DEBFULLNAME=${DEBFULLNAME:-"Grigory Tuboltsev"}
export DEBEMAIL=${DEBEMAIL:-"gtubolcev@gmail.com"}

# the next upload number for versions starting with $1 of source package $2:
# a version can be uploaded to the PPA only once, even after it was deleted
next_upload() {
  curl -fsS --retry 5 --retry-all-errors "https://api.launchpad.net/devel/${PPA_ARCHIVE}?ws.op=getPublishedSources&source_name=$2&exact_match=true" \
    | python3 -c 'import json, sys
prefix = sys.argv[1]
nums = [e["source_package_version"][len(prefix):] for e in json.load(sys.stdin)["entries"]
        if e["source_package_version"].startswith(prefix)]
print(max((int(n) for n in nums if n.isdigit()), default=0) + 1)' "$1"
}

rm -rf "$WORK"
"$ROOT/scripts/source.sh" "$WORK/src"
cd "$WORK/src"
SOURCE=$(dpkg-parsechangelog -S Source)
UPSTREAM=$(dpkg-parsechangelog -S Version)
if [ -n "${RELEASE:-}" ] && [ "$RELEASE" != "v$UPSTREAM" ]; then
  echo "error: tag $RELEASE, but debian/changelog has $UPSTREAM" >&2
  exit 1
fi
VERSION="$UPSTREAM~$DIST~ppa"
VERSION=$VERSION$(next_upload "$VERSION" "$SOURCE")
dch --newversion "$VERSION" --force-bad-version --distribution "$DIST" \
  --force-distribution "Build for $DIST (https://github.com/gtubolcev/thunar-disk-usage)."

# a native package: the tarball is the whole source and must be uploaded
if [ -n "${NO_UPLOAD:-}" ]; then
  dpkg-buildpackage -S -d -nc -us -uc
  exit 0
fi
dpkg-buildpackage -S -d -nc ${SIGN_KEY:+--sign-key="$SIGN_KEY"}
cd ..
dput "$PPA" ./*_source.changes
