# Scripts Layout

Platform-specific helpers were moved out of the repository root.

## Windows

Windows scripts live in `tools/scripts/windows/`.

Root wrappers kept for convenience:
- `build.bat`
- `docker-compose-up.bat`
- `docker-compose-down.bat`

## Linux

Linux scripts live in `tools/scripts/linux/`.

Common commands:
- `tools/scripts/linux/docker-compose-up.sh`
- `tools/scripts/linux/docker-compose-down.sh`
- `tools/scripts/linux/build.sh`
- `tools/scripts/linux/run.sh`
- `tools/scripts/linux/build-onnx.sh`
- `tools/scripts/linux/run-onnx.sh`
