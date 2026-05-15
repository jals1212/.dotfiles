.PHONY: build test install clean run docker-test docker-interactive docker-shell docker-clean

BINARY=dots
GOCACHE ?= /private/tmp/dotfiles-go-build

build:
	cd installer && GOCACHE=$(GOCACHE) go build -o ../$(BINARY) ./cmd/dots

test:
	cd installer && GOCACHE=$(GOCACHE) go test ./...

install: build
	cp $(BINARY) /usr/local/bin/

clean:
	rm -f $(BINARY)

run: build
	./$(BINARY)

# Docker testing
docker-test: build
	docker build -f installer/Dockerfile -t dots-test .
	docker run --rm dots-test ./installer/e2e/e2e_test.sh

docker-interactive: build
	docker build -f installer/Dockerfile -t dots-test .
	docker run --rm -it dots-test ./dots

docker-shell: build
	docker build -f installer/Dockerfile -t dots-test .
	docker run --rm -it dots-test /bin/bash

docker-clean:
	docker rmi dots-test 2>/dev/null || true
