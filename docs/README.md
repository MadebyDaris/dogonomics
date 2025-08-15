# Dogonomics

Dogonomics is a Go-based project designed to provide insights and analytics related to dog-related data. This README serves as comprehensive documentation for understanding the structure, usage, and resources of the project.

This repository cis plit into two branches the frontend deisgn of the applicaiton and the backend API handling and the main feature of Dogonomics is the go-based ONNX runtime financial data analysis with news sentiment. For now I am focusing on just basic news sentiment information before any major analysis.

If you want to take a look at the frontend switch branch and you can see the flutter application implementation.

## Table of Contents

- [Dogonomics](#dogonomics)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Using install Scripts](#using-install-scripts)
    - [Installation (Deprecating)](#installation-deprecating)
    - [Environment Variables](#environment-variables)
  - [Backend FinBERT-ONNX integration](#backend-finbert-onnx-integration)
      - [Version Compatibility Issues](#version-compatibility-issues)
      - [PyTorch Attention Mechanism Changes](#pytorch-attention-mechanism-changes)
      - [Go Integration Challenges](#go-integration-challenges)

---

## Overview

Dogonomics aggregates, analyzes, and serves data about dogs, including breeds, statistics, and trends. It exposes a RESTful API for client applications and provides utilities for data ingestion and processing.

## Getting Started

### Prerequisites
- TDM-GCC: Download from https://jmeubank.github.io/tdm-gcc/
- Go 1.18 or later
- Git
- (Optional to be implemented) Docker

### Using install Scripts
```sh
# 1. Install ONNX Runtime
setup_onnx.bat

# 2. Build application  
build.bat

# 3. Run server
run.bat
Scripts
```

The setup scripts will handle all the complex CGO environment variables, ONNX Runtime installation, and build configuration automatically. If you still encounter issues, the error messages will now be much more helpful and point you to specific solutions.

### Installation (Deprecating)
1. Clone the repository:
    ```sh
    git clone https://github.com/yourusername/dogonomics.git
    cd dogonomics
    ```

2. Install dependencies:
    ```sh
    go mod tidy
    ```

3. Build the project:
    ```sh
    go build ./...
    ```

4. Run the application:
    ```sh
    go run dogonomics.go
    ```

### Environment Variables

Create a `.env` file in the root directory with the following variables as needed:

## Backend FinBERT-ONNX integration
The main issue wasn't getting the model to work but the integration ONNX is very version dependant, and using a version of ONNX runtime different from the one the model was compiled in. As well as some features may not be fummy implemented in ONNX.

#### Version Compatibility Issues
ONNX Runtime 1.17.1 for ort(github.com/yalue/onnxruntime_go) only supports API versions 1-17, but newer PyTorch versions export models with higher opset versions (14+) that require API version 22+. This creates an immediate incompatibility where the model simply cannot load. 

#### PyTorch Attention Mechanism Changes
Modern PyTorch uses scaled_dot_product_attention which requires ONNX opset version 14 minimum. Older ONNX Runtime versions don't support this operator, requiring the use of legacy attention mechanisms by disabling the newer implementations.

#### Go Integration Challenges
The Go ONNX Runtime binding (github.com/yalue/onnxruntime_go) must match the installed ONNX Runtime version as well as the opset that the model was exported with, has to be compatible with the ONNX runtime version.
Windows requires specific ONNX Runtime installation paths (C:\onnxruntime) and proper CGO environment variables. The runtimesetup.bat script automates this process but version mismatches can still occur if the downloaded runtime doesn't match the Go binding expectations.