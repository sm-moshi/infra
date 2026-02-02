.PHONY: build clean install test

BINARY_NAME=gitops-guard

build:
	go build -ldflags="-s -w" -o $(BINARY_NAME) .

clean:
	rm -f $(BINARY_NAME)

install:
	go install .

test:
	go test -v ./...

fmt:
	go fmt ./...
