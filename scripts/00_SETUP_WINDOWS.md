# Windows Setup Quick Guide

Use this order for the fastest local backend setup.

## Standard Backend (No ONNX)

```powershell
cd dogonomics_go_backened
./scripts/dev.ps1 local
```

## ONNX + FinBERT Variant

```powershell
cd dogonomics_go_backened
./scripts/dev.ps1 local-onnx
```

## Docker Variant

```powershell
cd dogonomics_go_backened
./scripts/dev.ps1 docker-up
```

See `docs/setup/ONBOARDING.md` for full details.
