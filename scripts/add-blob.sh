#!/usr/bin/env bash
# Usage: scripts/add-blob.sh [VERSION] [SHA256]
#
# Fetch the wireguard-tools source tarball and register it with the BOSH
# blobstore. Must be run from the release root directory.
#
# Arguments:
#   VERSION   wireguard-tools version, e.g. 1.0.20260223 (default: 1.0.20260223)
#   SHA256    expected sha256 of the tarball; overrides the built-in table
#
# Prerequisites:
#   - bosh CLI in PATH
#   - config/private.yml populated with S3 blobstore credentials
#
# After running this script, execute:
#   bosh upload-blobs
set -e -u -o pipefail

VERSION="${1:-1.0.20260223}"
SHA_OVERRIDE="${2:-}"

ASSET="wireguard-tools-${VERSION}.tar.xz"
# Primary: signed release tarballs. Fallback: cgit snapshot of the tag.
URL="https://git.zx2c4.com/wireguard-tools/snapshot/${ASSET}"

# Known-good sha256 sums for verified versions. Extend as versions are adopted.
declare -A KNOWN_SHA256=(
  ["1.0.20210914"]="97ff31489217bb265b7ae850d3d0f335ab07d2652ba1feec88b734bc96bd05ac"
  ["1.0.20260223"]="af459827b80bfd31b83b08077f4b5843acb7d18ad9a33a2ef532d3090f291fbf"
)

EXPECTED="${SHA_OVERRIDE:-${KNOWN_SHA256[${VERSION}]:-}}"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

echo "==> Fetching ${URL}"
if ! curl -fL --progress-bar -o "${TMP}/${ASSET}" "${URL}"; then
  echo "ERROR: download failed — verify VERSION '${VERSION}' exists at" >&2
  echo "       https://git.zx2c4.com/wireguard-tools/refs/" >&2
  exit 1
fi

ACTUAL=$(shasum -a 256 "${TMP}/${ASSET}" 2>/dev/null | awk '{print $1}')
[[ -n "${ACTUAL}" ]] || ACTUAL=$(sha256sum "${TMP}/${ASSET}" | awk '{print $1}')

if [[ -n "${EXPECTED}" ]]; then
  if [[ "${EXPECTED}" != "${ACTUAL}" ]]; then
    echo "ERROR: SHA256 mismatch" >&2
    echo "  expected: ${EXPECTED}" >&2
    echo "  actual:   ${ACTUAL}" >&2
    exit 1
  fi
  echo "==> SHA256 OK: ${ACTUAL}"
else
  echo "WARN: no known sha256 for ${VERSION}; recording actual for review:" >&2
  echo "  ${ACTUAL}  ${ASSET}" >&2
  echo "  Verify against upstream signatures, then add to KNOWN_SHA256." >&2
fi

# Register blob with BOSH blobstore under the key expected by
# packages/wireguard-tools/spec.
BLOB_KEY="wireguard-tools/${ASSET}"
echo "==> Adding blob as ${BLOB_KEY}"
bosh add-blob "${TMP}/${ASSET}" "${BLOB_KEY}"

echo ""
echo "Done. Run 'bosh upload-blobs' to push to the blobstore."
echo "Then run 'bosh create-release' or 'bosh create-release --final' as needed."
