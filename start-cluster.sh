#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Ensure external network exists (Compose expects 'apache' external)
docker network create --driver=bridge apache >/dev/null 2>&1 || true

# Start cluster
docker compose up -d

# Show status
docker compose ps
