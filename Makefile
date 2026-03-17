.PHONY: help build test lint run clean docker-build docker-run docker-shell examples

help:
	@echo "Solidity Zig Decompiler - Make Commands"
	@echo ""
	@echo "  make build         Build the project"
	@echo "  make test         Run tests"
	@echo "  make lint         Check code formatting"
	@echo "  make run          Run the decompiler"
	@echo "  make clean        Clean build artifacts"
	@echo "  make examples     Build all examples"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-build Build Docker image"
	@echo "  make docker-run   Run in Docker"
	@echo ""

build:
	zig build

test:
	zig build test

lint:
	zig fmt --check .

run:
	zig build run

clean:
	rm -rf zig-out zig-cache

examples:
	@echo "Building examples..."
	@zig run examples/01_parse_bytecode.zig
	@zig run examples/02_resolve_signatures.zig
	@zig run examples/03_extract_strings.zig
	@zig run examples/04_defi_detection.zig
	@echo "All examples built!"

docker-build:
	docker build -t solidity-zig-decompiler .

docker-run:
	docker run --rm -it solidity-zig-decompiler

docker-shell:
	docker build -t solidity-zig-decompiler .
	docker run --rm -it solidity-zig-decompiler /bin/sh

docker-compose-build:
	docker-compose build

docker-compose-run:
	docker-compose run --rm decompiler

docker-compose-shell:
	docker-compose run --rm shell
