# Backend Scripts

This folder is the new script entrypoint layout for backend operations.

## Quick Start

Use one command hub for straightforward usage:

- `./scripts/dev.ps1 help`
- `./scripts/dev.ps1 local`
- `./scripts/dev.ps1 docker-up`
- `./scripts/dev.ps1 docker-up-onnx`

## Structure

- `build/` - Build commands (standard and ONNX)
- `run/` - Runtime commands
- `database/` - Local PostgreSQL setup and validation
- `docker/` - Docker compose and image helpers
- `onnx/` - ONNX runtime setup helpers
- `batch/` - Structured batch wrappers grouped by domain

## Recommended Usage (Windows)

Use PowerShell scripts as primary entrypoints:

- `scripts/build/build.ps1`
- `scripts/build/build-onnx.ps1`
- `scripts/run/run.ps1`
- `scripts/run/run-onnx.ps1`
- `scripts/database/setup-postgres-local.ps1`
- `scripts/database/test-db-connection.ps1`
- `scripts/docker/docker-compose-up.ps1`
- `scripts/docker/docker-compose-down.ps1`

Root batch clutter was reduced.
Use `dev.bat` or `scripts/dev.ps1` as the primary entrypoint.
If needed, grouped batch files are under `scripts/batch/`.

## Legacy Archive

- `legacy/python/` contains archived Python utilities that are no longer part of the active backend workflow.
- `legacy/windows-scripts/` contains previous verbose Windows setup scripts used behind current wrappers.
