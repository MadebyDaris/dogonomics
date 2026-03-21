# Layout Migration Roadmap

This file tracks migration from current backend structure toward `golang-standards/project-layout`.

## Phase Status

- [x] Phase 1: Script and docs organization
- [x] Phase 1: Target directory skeleton created (`cmd`, `internal` domains, `assets`, `migrations`)
- [x] Phase 2: Add `cmd/dogonomics` entrypoint and switch build scripts to target it
- [x] Phase 2: Internalize sentiment feature code (now under `internal/service/sentiment`)
- [x] Phase 3: Move clients to `internal/api/*`
- [x] Phase 4: Move middleware and handlers under `internal/*`
- [x] Phase 5: Move sentiment/inference services under `internal/service/*`
- [x] Phase 6: Path and Docker alignment
- [x] Phase 7: Cleanup and deprecate old paths
- [x] Phase 8: Straightforward script UX and archive non-Go tooling

## Non-Functional Constraints

- Keep API behavior unchanged.
- Keep middleware order unchanged.
- Keep security controls unchanged.
- Keep ONNX/non-ONNX build behavior unchanged.
