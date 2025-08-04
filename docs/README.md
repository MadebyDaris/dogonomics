# Dogonomics Project

Dogonomics is a Go-based project designed to provide insights and analytics related to dog-related data. This README serves as comprehensive documentation for understanding the structure, usage, and resources of the project.

## Table of Contents

- [Dogonomics Project](#dogonomics-project)
  - [Table of Contents](#table-of-contents)
  - [Overview](#overview)
  - [Getting Started](#getting-started)
    - [Prerequisites](#prerequisites)
    - [Installation](#installation)
    - [Environment Variables](#environment-variables)

---

## Overview

Dogonomics aggregates, analyzes, and serves data about dogs, including breeds, statistics, and trends. It exposes a RESTful API for client applications and provides utilities for data ingestion and processing.

## Getting Started

### Prerequisites

- Go 1.18 or later
- Git
- (Optional) Docker

### Installation

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
    go run main.go
    ```

### Environment Variables

Create a `.env` file in the root directory with the following variables as needed:
