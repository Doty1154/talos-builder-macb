#!/usr/bin/env bash
#
# Update the raspberrypi/linux kernel reference in both patch files.
# Takes a branch or tag name, resolves it to a commit on GitHub, downloads
# the tarball, computes sha256/sha512, extracts the kernel version from the
# top-level Makefile, and rewrites both patch files in place.
#
# Usage: ./update-rpi-kernel.sh <branch-or-tag>
# Example: ./update-rpi-kernel.sh rpi-6.18.y
#

set -euo pipefail

if [ $# -ne 1 ]; then
    echo "Usage: $0 <branch-or-tag>" >&2
    echo "Example: $0 rpi-6.18.y" >&2
    exit 1
fi

REF="$1"
REPO="raspberrypi/linux"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKGS_PATCH="${REPO_ROOT}/patches/siderolabs/pkgs/0001-Patched-for-Raspberry-Pi-5.patch"
SBC_PATCH="${REPO_ROOT}/patches/siderolabs/sbc-raspberrypi/0001-Patched-for-Raspberry-Pi-5.patch"

for f in "$PKGS_PATCH" "$SBC_PATCH"; do
    if [ ! -f "$f" ]; then
        echo "Missing patch file: $f" >&2
        exit 1
    fi
done

for cmd in curl tar perl awk shasum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Required command not found: $cmd" >&2
        exit 1
    fi
done

echo "Resolving ${REPO}@${REF}..."
COMMIT_JSON=$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO}/commits/${REF}")

FULL_SHA=$(printf '%s' "$COMMIT_JSON" | awk -F'"' '/"sha":/ {print $4; exit}')
if [ -z "$FULL_SHA" ]; then
    echo "Could not resolve commit SHA for ${REF}" >&2
    exit 1
fi
SHORT_SHA="${FULL_SHA:0:12}"

# Use the committer date, which is what shows up on the GitHub commit page.
COMMIT_DATE=$(printf '%s' "$COMMIT_JSON" \
    | awk '/"committer":/{found=1} found && /"date":/{print; exit}' \
    | awk -F'"' '{print $4}' \
    | cut -d'T' -f1)

echo "  commit: $FULL_SHA"
echo "  short:  $SHORT_SHA"
echo "  date:   $COMMIT_DATE"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
TARBALL="${TMPDIR}/rpi-linux.tar.gz"

echo "Downloading tarball..."
curl -fsSL -o "$TARBALL" "https://github.com/${REPO}/archive/${FULL_SHA}.tar.gz"

echo "Computing checksums..."
SHA256=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
SHA512=$(shasum -a 512 "$TARBALL" | awk '{print $1}')
echo "  sha256: $SHA256"
echo "  sha512: $SHA512"

echo "Extracting kernel version from Makefile..."
tar -xzf "$TARBALL" -C "$TMPDIR" "linux-${FULL_SHA}/Makefile"
MAKEFILE="${TMPDIR}/linux-${FULL_SHA}/Makefile"
V=$(awk '/^VERSION[[:space:]]*=/ {print $3; exit}' "$MAKEFILE")
P=$(awk '/^PATCHLEVEL[[:space:]]*=/ {print $3; exit}' "$MAKEFILE")
S=$(awk '/^SUBLEVEL[[:space:]]*=/ {print $3; exit}' "$MAKEFILE")
KERNEL_VERSION="${V}.${P}.${S}"
echo "  kernel: $KERNEL_VERSION"

COMMENT="# ${REF} branch, commit ${SHORT_SHA} (${COMMIT_DATE}), kernel ${KERNEL_VERSION}"

update_field() {
    local file="$1" key="$2" value="$3"
    FIELD="$key" VALUE="$value" perl -i -pe '
        my $k = quotemeta($ENV{FIELD});
        s/^(\+\s*${k}:\s*).*/$1$ENV{VALUE}/;
    ' "$file"
}

update_comment() {
    local file="$1"
    COMMENT="$COMMENT" perl -i -pe '
        s{^(\+\s*)#\s*\S+\s+branch,\s*commit\s+[0-9a-f]+\s*\([^)]*\),\s*kernel\s+\S+.*}
         {$1$ENV{COMMENT}};
    ' "$file"
}

echo "Updating $PKGS_PATCH..."
update_field "$PKGS_PATCH" "linux_version" "$SHORT_SHA"
update_field "$PKGS_PATCH" "linux_sha256" "$SHA256"
update_field "$PKGS_PATCH" "linux_sha512" "$SHA512"
update_comment "$PKGS_PATCH"

echo "Updating $SBC_PATCH..."
update_field "$SBC_PATCH" "raspberrypi_kernel_version" "$SHORT_SHA"
update_field "$SBC_PATCH" "raspberrypi_kernel_sha256" "$SHA256"
update_field "$SBC_PATCH" "raspberrypi_kernel_sha512" "$SHA512"
update_comment "$SBC_PATCH"

echo "Done."
