# Makefile for Blink_ESP32S3
# ESP32-S3 Arduino Project

BASE_DIR=$(shell cd "$(shell dirname "$(shell readlink -f "$(MAKEFILE_LIST)" || echo "$(MAKEFILE_LIST)")")/.." && pwd)
PORT ?= $(shell $(BASE_DIR)/_scripts/esp32-detect-port.sh 2>/dev/null || echo /dev/ttyUSB0)
FQBN ?= esp32:esp32:esp32s3
SKETCH ?= .
JOBS ?= $(shell nproc)
BAUDRATE ?= 115200

.DEFAULT_GOAL := help

.PHONY: help build upload monitor clean all list-boards

help:
	@echo "Blink_ESP32S3 - ESP32-S3 Arduino Project"
	@echo ""
	@echo "Commands:"
	@echo "  make build        - Compile the sketch"
	@echo "  make upload       - Compile and upload to board"
	@echo "  make monitor      - Open serial monitor"
	@echo "  make all          - Upload and monitor"
	@echo "  make clean        - Clean build cache"
	@echo "  make list-boards  - List connected boards"
	@echo ""
	@echo "Configuration:"
	@echo "  PORT=$(PORT)"
	@echo "  FQBN=$(FQBN)"

build:
	@echo "🔨 Compiling..."
	arduino-cli compile -j $(JOBS) --fqbn $(FQBN) $(SKETCH)

upload: build
	@echo "📤 Uploading to $(PORT)..."
	arduino-cli upload -p $(PORT) --fqbn $(FQBN) $(SKETCH)

monitor:
	@echo "📡 Opening serial monitor on $(PORT) at $(BAUDRATE) baud..."
	arduino-cli monitor -p $(PORT) --config baudrate=$(BAUDRATE)

all: upload monitor

clean:
	@echo "🧹 Cleaning build cache..."
	arduino-cli cache clean

list-boards:
	@echo "🔌 Connected boards:"
	arduino-cli board list
