# ONNX + FinBERT Setup

## Goal

Enable local ONNX-backed sentiment inference.

## Install Runtime

```powershell
./scripts/onnx/install-runtime.ps1
```

## Build and Run ONNX Binary

```powershell
./scripts/build/build-onnx.ps1
./scripts/run/run-onnx.ps1
```

## Runtime Guards

The backend enforces serialized FinBERT execution by default.

Tunable env vars:

- `BERT_MAX_CONCURRENCY` (recommended `1`)
- `BERT_QUEUE_TIMEOUT_SECONDS`

## Primary Sentiment Endpoints

- `POST /finbert/inference`
- `GET /finnewsBert/:symbol`
- `GET /sentiment/:symbol`
- `GET /news/general/sentiment`
