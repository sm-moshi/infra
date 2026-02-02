.PHONY: build build-all clean install test

BINARY_NAME=helm-scaffold
VERSION?=0.1.0

# Build for current platform
build:
	go build -ldflags="-s -w" -o $(BINARY_NAME) .

# Build for all platforms
build-all: clean
	GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o dist/$(BINARY_NAME)-linux-amd64 .
	GOOS=darwin GOARCH=arm64 go build -ldflags="-s -w" -o dist/$(BINARY_NAME)-darwin-arm64 .
	GOOS=darwin GOARCH=amd64 go build -ldflags="-s -w" -o dist/$(BINARY_NAME)-darwin-amd64 .
	GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o dist/$(BINARY_NAME)-windows-amd64.exe .

# Clean build artifacts
clean:
	rm -f $(BINARY_NAME)
	rm -rf dist/

# Install to $GOPATH/bin
install:
	go install .

# Run tests
test:
	go test -v ./...

# Format code
fmt:
	go fmt ./...

# Run linter
lint:
	golangci-lint run

# Build and test locally
dev: fmt build
	./$(BINARY_NAME) --help
