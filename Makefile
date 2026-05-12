.PHONY: build install clean run

BINARY=dots

build:
	go build -o $(BINARY) ./cmd/dots

install: build
	cp $(BINARY) /usr/local/bin/

clean:
	rm -f $(BINARY)

run: build
	./$(BINARY)

# Docker testing
docker-test: build
	docker build -t dots-test .
	docker run --rm dots-test ./e2e/test.sh

docker-interactive: build
	docker build -t dots-test .
	docker run --rm -it dots-test ./dots

docker-shell: build
	docker build -t dots-test .
	docker run --rm -it dots-test /bin/bash

docker-clean:
	docker rmi dots-test 2>/dev/null || true