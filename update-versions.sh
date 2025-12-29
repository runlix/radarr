#!/bin/bash
#
# update-versions.sh - Update Radarr version and package URLs in VERSION.json
#
# This script queries the Radarr GitHub releases API for the latest release
# and updates the version, sbranch, and package_url fields in VERSION.json.
# When the version changes, build_date is also updated.
#
# Usage:
#   ./update-versions.sh
#
# Requirements:
#   - jq: JSON processor
#   - curl: HTTP client
#   - VERSION.json: Must exist in the same directory
#
# Exit Codes:
#   0: Success
#   1: Error (missing tools, API failure, etc.)

set -euo pipefail

# Fetch Radarr release information from GitHub releases API
release_json=$(curl -fsSL "https://api.github.com/repos/Radarr/Radarr/releases/latest") || exit 1

# Extract version and tag
tag_name=$(jq -re '.tag_name' <<< "${release_json}")
version="${tag_name#v}"  # Remove 'v' prefix if present
sbranch="main"  # Radarr uses 'main' branch for stable releases

# Extract package URLs for each architecture from release assets
amd64_url=$(jq -re '.assets[] | select(.name | contains("linux-core-x64")) | .browser_download_url' <<< "${release_json}")
arm64_url=$(jq -re '.assets[] | select(.name | contains("linux-core-arm64")) | .browser_download_url' <<< "${release_json}")

# Read current VERSION.json
json=$(cat VERSION.json)
current_version=$(jq -r '.version' <<< "${json}")
changed=false

# Check if version changed
if [ "$current_version" != "$version" ]; then
    changed=true
    echo "Version changed: ${current_version} -> ${version}"
fi

# Update root-level version and sbranch
json=$(jq --arg version "$version" \
          --arg sbranch "$sbranch" \
          '.version = $version | .sbranch = $sbranch' <<< "${json}")

# Get the number of targets
target_count=$(jq '.targets | length' <<< "${json}")

# Update package_url for each target based on architecture
for i in $(seq 0 $((target_count - 1))); do
    arch=$(jq -re ".targets[${i}].arch" <<< "${json}")
    
    # Determine which URL to use based on architecture
    if [ "$arch" = "linux-amd64" ]; then
        new_url="$amd64_url"
    elif [ "$arch" = "linux-arm64" ]; then
        new_url="$arm64_url"
    else
        echo "Warning: Unknown architecture '${arch}', skipping package_url update"
        continue
    fi
    
    # Update package_url for this target
    json=$(jq --arg idx "$i" --arg url "$new_url" \
        '.targets[$idx | tonumber].package_url = $url' <<< "${json}")
    
    echo "Updated package_url for ${arch} target"
done

# Update build_date if version changed
if [ "$changed" = true ]; then
    json=$(jq --arg build_date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              '.build_date = $build_date' <<< "${json}")
    echo "Updated build_date"
fi

# Write updated VERSION.json
jq --sort-keys . <<< "${json}" | tee VERSION.json

