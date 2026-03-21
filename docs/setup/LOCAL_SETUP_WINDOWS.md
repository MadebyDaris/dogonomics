# Local Setup (Windows)

## Recommended Scripts (PowerShell Primary)

From backend root:

```powershell
./scripts/database/setup-postgres-local.ps1
./scripts/build/build.ps1
./scripts/run/run.ps1
```

## ONNX Variant

```powershell
./scripts/onnx/install-runtime.ps1
./scripts/build/build-onnx.ps1
./scripts/run/run-onnx.ps1
```

## Validate

- API: http://localhost:8080
- Swagger: http://localhost:8080/swagger/index.html
- Metrics: http://localhost:8080/metrics

## Notes

Legacy `.bat` scripts remain available and now forward to the new script layout.
