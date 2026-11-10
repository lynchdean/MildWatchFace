#!/bin/bash
# Local, manual build-check across one representative device per
# resourcePath/annotation bucket in monkey.jungle. Not run in CI —
# see .github/workflows/validate.yml for why (Garmin SDK access needs
# account credentials CI shouldn't hold). Run this yourself, using your
# own locally installed Connect IQ SDK, before anything you care about
# shipping (a release, or after touching monkey.jungle/manifest.xml).
#
# Usage:
#   ./scripts/compile-check.sh
#
# Override the SDK or key location if needed:
#   CIQ_SDK=/path/to/sdk CIQ_KEY=/path/to/developer_key ./scripts/compile-check.sh

set -u
cd "$(dirname "$0")/.."

# Pick the newest installed SDK unless CIQ_SDK is set.
SDK="${CIQ_SDK:-$(ls -d ~/Library/Application\ Support/Garmin/ConnectIQ/Sdks/*/ 2>/dev/null | sort -V | tail -1)}"
KEY="${CIQ_KEY:-}"

if [ -z "$SDK" ] || [ ! -x "$SDK/bin/monkeyc" ]; then
  echo "Could not find a Connect IQ SDK. Set CIQ_SDK=/path/to/sdk." >&2
  exit 1
fi
if [ -z "$KEY" ] || [ ! -f "$KEY" ]; then
  echo "Set CIQ_KEY=/path/to/developer_key (your Connect IQ signing key)." >&2
  exit 1
fi

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# One representative device per distinct resourcePath bucket + CIQ1,
# so every settings.xml variant and every hasBitmap2/noBitmap2/ciq1
# annotation combination actually used in the code gets compiled.
DEVICES=(
  epix2    # default bucket (AMOLED, hasBitmap2, ciq2plus)
  venu2    # amoled-noradialtext (hasBitmap2, ciq2plus)
  venu     # amoled-nobitmap2 (noBitmap2, ciq2plus)
  fenix7   # mips-radialtext (hasBitmap2, ciq2plus)
  fr255    # mips-bitmap2 (hasBitmap2, ciq2plus)
  fenix6   # mips, no bitmap2/radialtext (noBitmap2, ciq2plus)
  fr55     # mips-lesscolours (noBitmap2, ciq2plus)
  fr45     # ciq1 (noBitmap2, ciq1)
  fenix843mm # hasWatchFaceConfig (native on-device editor)
)

fail=0
for device in "${DEVICES[@]}"; do
  echo "=== $device ==="
  if ! "$SDK/bin/monkeyc" -o "$OUT/$device.prg" -f monkey.jungle -y "$KEY" -d "$device" -w 2>&1 | tee /dev/stderr | grep -q "BUILD SUCCESSFUL"; then
    echo "FAILED: $device"
    fail=1
  fi
done

if [ "$fail" -eq 0 ]; then
  echo
  echo "All representative devices built successfully."
else
  echo
  echo "One or more devices failed to build. See output above."
fi
exit "$fail"
