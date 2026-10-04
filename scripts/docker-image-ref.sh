#!/usr/bin/env bash
# Content-addressed dependency image shared by local builds and CI.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hash=$(cat "$root/docker/Dockerfile" "$root/docker/.dockerignore" | sha256sum | cut -d' ' -f1)
printf 'ghcr.io/wa101200/cartograph-build:deps-%s\n' "$hash"
