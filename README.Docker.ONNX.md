# Docker ONNX Build Guide

This guide explains how to build and run Dogonomics with BERT sentiment analysis enabled in Docker.

## Quick Start

### Option 1: Docker Compose (Recommended)

Run the ONNX-enabled service on port 8081:

```bash
docker compose --profile onnx up --build dogonomics-onnx
```

This will:
- Build the ONNX-enabled image using `Dockerfile.onnx`
- Install ONNX Runtime 1.17.1 in the container
- Enable CGO and build with `-tags onnx`
- Run on port 8081 (to avoid conflict with standard service on 8080)

### Option 2: Build and run manually

Build the ONNX-enabled image:

```bash
docker build -f Dockerfile.onnx -t dogonomics:onnx .
```

Run the container:

```bash
docker run --env-file .env -p 8080:8080 dogonomics:onnx
```

## Verify BERT is working

Once running, test a BERT endpoint:

```bash
curl http://localhost:8081/finnewsBert/AAPL
```

You should see `bert_sentiment` fields in the response with:
- `label`: "positive", "negative", or "neutral"
- `score`: sentiment score
- `confidence`: model confidence

The startup logs should show:
```
BERT model initialized successfully
```

Instead of:
```
ERROR: Failed to initialize BERT model: ONNX runtime disabled
```

## Standard vs ONNX builds

| Feature | Dockerfile | Dockerfile.onnx |
|---------|-----------|----------------|
| CGO | Disabled | Enabled |
| BERT sentiment | ❌ Stub only | ✅ Full ONNX inference |
| Binary size | ~15MB | ~25MB |
| Runtime deps | None | libonnxruntime.so |
| Build time | ~30s | ~2min |
| Ports (compose) | 8080 | 8081 |

## Run both services together

To run standard + ONNX + monitoring stack:

```bash
docker compose --profile onnx up --build
```

Services:
- Standard API: http://localhost:8080 (no BERT)
- ONNX API: http://localhost:8081 (with BERT)
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000

## Troubleshooting

**Build fails with "cannot find -lonnxruntime"**
- Ensure the ONNX download URL and version match in Dockerfile.onnx
- Check that the downloaded archive extracts `lib/libonnxruntime.so*`

**Runtime error: "error while loading shared libraries: libonnxruntime.so"**
- Verify COPY step copies ONNX libs to /usr/local/lib
- Ensure ldconfig runs in the final stage

**BERT still shows as disabled**
- Confirm you're using Dockerfile.onnx (check build logs for "Build with ONNX tag")
- Check that vocab files are copied: `/sentAnalysis/finbert/vocab.txt`
- Verify model file exists: `/sentAnalysis/DoggoFinBERT.onnx`

## Local development with ONNX

For local Windows development with ONNX:

1. Install ONNX Runtime to `C:\onnxruntime`
2. Set environment variables:
   ```powershell
   $env:CGO_ENABLED="1"
   $env:CGO_CFLAGS="-IC:\onnxruntime\include"
   $env:CGO_LDFLAGS="-LC:\onnxruntime\lib -lonnxruntime"
   $env:Path="$env:Path;C:\onnxruntime\lib"
   ```
3. Run with onnx tag:
   ```powershell
   go run -tags onnx .\dogonomics.go
   ```

Or use the provided batch scripts:
```cmd
runtimesetup.bat
build.bat
run.bat
```
