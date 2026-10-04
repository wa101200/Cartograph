#!/usr/bin/env bash
# Copy immutable integration templates once; generated binaries stay in the mount.
set -euo pipefail
project="${1:?Expected project root}"
template="${CARTOGRAPH_WWISE_TEMPLATE:-/opt/cartograph/wwise-plugins}"
for plugin in Wwise WwiseNiagara; do
  if [ -f "$project/Plugins/$plugin/$plugin.uplugin" ]; then continue; fi
  if [ ! -f "$template/$plugin/$plugin.uplugin" ]; then
    echo "Image is missing Wwise template: $template/$plugin/$plugin.uplugin" >&2
    exit 1
  fi
  echo "Initializing $plugin from the Docker image..."
  mkdir -p "$project/Plugins"
  # Do not overwrite an existing partial/user-edited plugin directory.
  if [ -e "$project/Plugins/$plugin" ]; then
    echo "Incomplete plugin already exists: $project/Plugins/$plugin. Refusing to overwrite it." >&2
    exit 1
  fi
  cp -a --reflink=auto "$template/$plugin" "$project/Plugins/$plugin"
  chmod -R u+w "$project/Plugins/$plugin"
done
