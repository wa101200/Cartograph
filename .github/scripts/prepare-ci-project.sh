#!/usr/bin/env bash
set -euo pipefail
: "${PROJECT_ROOT:?}"
: "${GITHUB_WORKSPACE:?}"
# Preserve generated outputs and licensed Wwise integration, but synchronize
# tracked inputs by content so identical files keep their cached modification time.
rsync -a --no-times --checksum --delete \
  --exclude='.git' \
  --exclude='lost+found/' \
  --exclude='Binaries/' --exclude='Intermediate/' --exclude='Saved/' \
  --exclude='DerivedDataCache/' \
  --exclude='Plugins/Wwise/' --exclude='Plugins/WwiseNiagara/' \
  "$GITHUB_WORKSPACE/" "$PROJECT_ROOT/"

if [ -e "$PROJECT_ROOT/.git" ] && [ ! -L "$PROJECT_ROOT/.git" ]; then
  echo 'Unexpected .git directory in the generated-output cache; refusing to replace it.' >&2
  exit 1
fi
# Only a link is persisted, not checkout credentials or Git configuration.
ln -sfn "$GITHUB_WORKSPACE/.git" "$PROJECT_ROOT/.git"

# The shared container-side build script owns UBT settings. Do not rewrite them
# here: two serializers would change timestamps and invalidate warm builds.
