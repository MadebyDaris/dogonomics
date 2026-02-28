# Build stage
# syntax=docker/dockerfile:1.6

ARG TARGETOS=linux
ARG TARGETARCH=amd64
FROM --platform=$BUILDPLATFORM golang:1.24.5-alpine AS builder
WORKDIR /app

# Install git and certificates (needed for fetching modules)
RUN apk add --no-cache git ca-certificates

# Use the public Go module proxy and checksum DB to avoid checksum mismatches
ENV GOPROXY=https://proxy.golang.org
ENV GOSUMDB=sum.golang.org

 # Copy go files and vendor to avoid external downloads (deterministic builds)
COPY go.mod go.sum ./

# Copy the rest of the source (includes vendor/ if present)
COPY . ./

# Generate swagger docs (optional) if you need to refresh the docs inside the image
# RUN go install github.com/swaggo/swag/cmd/swag@latest
# RUN swag init -g dogonomics.go -o docs

# Build a static binary for target platform
ENV GOFLAGS=-buildvcs=false
RUN --mount=type=cache,target=/root/.cache/go-build \
	CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH sh -c 'if [ -d vendor ]; then MOD="-mod=vendor"; else go mod download; MOD=""; fi; \
	go build $MOD -ldflags="-s -w" -trimpath -o /out/dogonomics ./'

# Final stage
FROM --platform=$TARGETOS/$TARGETARCH alpine:latest
RUN apk add --no-cache ca-certificates
WORKDIR /
COPY --from=builder /out/dogonomics /dogonomics
COPY --from=builder /app/sentAnalysis/DoggoFinBERT.onnx /sentAnalysis/DoggoFinBERT.onnx

EXPOSE ${PORT:-8080}
ENV PORT=8080
ENTRYPOINT ["/dogonomics"]
