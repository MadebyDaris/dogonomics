# Script Guide

## Straightforward Usage

Use the command hub:

```powershell
./scripts/dev.ps1 help
./scripts/dev.ps1 local
./scripts/dev.ps1 docker-up
./scripts/dev.ps1 docker-up-onnx
```

## New Layout

- `scripts/build/`
- `scripts/run/`
- `scripts/database/`
- `scripts/docker/`
- `scripts/onnx/`
- `scripts/batch/`

## Policy

- PowerShell scripts are primary.
- Use `dev.bat` at root if you prefer batch.
- Additional batch wrappers are organized under `scripts/batch/*`.

## Common Workflows

### Standard local run

```powershell
./scripts/dev.ps1 build
./scripts/dev.ps1 run
```

### ONNX local run

```powershell
./scripts/dev.ps1 local-onnx
```

### Database setup and test

```powershell
./scripts/dev.ps1 db-setup
./scripts/dev.ps1 db-test
```

### Docker

```powershell
./scripts/dev.ps1 docker-up
./scripts/dev.ps1 docker-down
```
