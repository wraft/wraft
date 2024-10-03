# Makefile for Wraft

# Variables
SHELL := /bin/bash
ENV_FILE := .env.dev

# Phony targets
.PHONY: setup deps db run test docker-up docker-down

# Default target
all: setup

# Setup the development environment
setup: deps db

# Install dependencies
deps:
	@echo "Installing dependencies..."
	mix deps.get

# Setup the database
db:
	@echo "Setting up the database..."
	mix ecto.setup

# Run the application
run:
	@echo "Starting Wraft..."
	source $(ENV_FILE) && mix phx.server

# Run tests
test:
	@echo "Running tests..."
	mix test

# Start Docker containers
docker-up:
	@echo "Starting Docker containers..."
	docker-compose up -d

# Stop Docker containers
docker-down:
	@echo "Stopping Docker containers..."
	docker-compose down

# Install system dependencies (for Ubuntu)
install-deps-ubuntu:
	@echo "Installing system dependencies for Ubuntu..."
	sudo apt-get update
	sudo apt-get install -y inotify-tools postgresql pandoc texlive-full

# Install system dependencies (for macOS)
install-deps-macos:
	@echo "Installing system dependencies for macOS..."
	brew install inotify-tools postgresql pandoc
	# Note: MacTeX should be installed manually from https://www.tug.org/mactex/

# Help target
help:
	@echo "Available targets:"
	@echo "  setup         - Set up the development environment"
	@echo "  deps          - Install Elixir dependencies"
	@echo "  db            - Set up the database"
	@echo "  run           - Run the Wraft application"
	@echo "  test          - Run tests"
	@echo "  docker-up     - Start Docker containers"
	@echo "  docker-down   - Stop Docker containers"
	@echo "  install-deps-ubuntu - Install system dependencies for Ubuntu"
	@echo "  install-deps-macos  - Install system dependencies for macOS"
	@echo "  help          - Show this help message"