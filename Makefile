# Makefile for Wraft

# Variables
ifeq ($(OS),Windows_NT)
	SHELL := powershell.exe
	ENV_FILE := .env
	DETECTED_OS := windows
else
	SHELL := /bin/bash
	ENV_FILE := .env
	UNAME_S := $(shell uname -s)
	ifeq ($(UNAME_S),Darwin)
		DETECTED_OS := macos
	else
		DETECTED_OS := linux
	endif
endif

# Required versions
REQUIRED_ELIXIR_VERSION := 1.19.2
REQUIRED_ERLANG_VERSION := 27.0.1
REQUIRED_PANDOC_VERSION := 3.6.3
REQUIRED_TYPST_VERSION := 0.13.0
REQUIRED_JAVA_VERSION := 17

# Phony targets
.PHONY: setup deps db run test docker-up docker-down check-deps check-env check-versions install-deps install-deps-ubuntu install-deps-macos install-deps-windows troubleshoot

# Default target
all: setup

# Setup the development environment
setup: check-env deps check-versions check-deps db

# Install dependencies
deps:
	@echo "Installing dependencies..."
	mix deps.get

# Check system dependencies
check-deps:
	@echo "Checking system dependencies..."
	mix setup.deps

# Setup the database
db:
	@echo "Setting up the database, creating bucket and running migrations..."
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
	@echo "🚀 Installing system dependencies for Ubuntu..."
	@echo "This may take a while. Please be patient..."
	
	@echo "\n📦 Installing system packages..."
	sudo apt-get update || { echo "❌ Failed to update package list. Check your internet connection."; exit 1; }
	sudo apt-get install -y \
		inotify-tools \
		postgresql \
		pandoc \
		texlive-full \
		imagemagick \
		openjdk-17-jdk \
		curl \
		build-essential \
		git \
		minio || { echo "❌ Failed to install system packages. See error above."; exit 1; }
	
	@echo "\n🦀 Installing Rust toolchain..."
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || { echo "❌ Failed to install Rust. Try installing manually from https://rustup.rs/"; exit 1; }
	. "$$HOME/.cargo/env"
	
	@echo "\n📝 Installing Typst..."
	cargo install typst-cli --version $(REQUIRED_TYPST_VERSION) || { echo "❌ Failed to install Typst. Make sure Rust is properly installed."; exit 1; }
	
	@echo "\n⚙️ Installing asdf version manager..."
	git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1 || true
	echo '. "$$HOME/.asdf/asdf.sh"' >> ~/.bashrc
	echo '. "$$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
	. "$$HOME/.asdf/asdf.sh"
	
	@echo "\n💫 Installing Erlang and Elixir..."
	asdf plugin add erlang || true
	asdf plugin add elixir || true
	asdf install erlang $(REQUIRED_ERLANG_VERSION) || { echo "❌ Failed to install Erlang. Try running 'asdf install erlang $(REQUIRED_ERLANG_VERSION) -v' for verbose output."; exit 1; }
	asdf install elixir $(REQUIRED_ELIXIR_VERSION) || { echo "❌ Failed to install Elixir. Try running 'asdf install elixir $(REQUIRED_ELIXIR_VERSION) -v' for verbose output."; exit 1; }
	asdf global erlang $(REQUIRED_ERLANG_VERSION)
	asdf global elixir $(REQUIRED_ELIXIR_VERSION)
	
	@echo "\n✅ System dependencies installed successfully!"
	@echo "⚠️  Please log out and log back in for all changes to take effect."
	@echo "📝 Next steps:"
	@echo "  1. Run 'make check-versions' to verify installations"
	@echo "  2. Run 'make setup' to complete the setup process"

# Auto-detect and install dependencies for the current OS
install-deps:
ifeq ($(DETECTED_OS),windows)
	@$(MAKE) install-deps-windows
else ifeq ($(DETECTED_OS),macos)
	@$(MAKE) install-deps-macos
else
	@$(MAKE) install-deps-ubuntu
endif

# Install system dependencies (for macOS)
install-deps-macos:
	@echo "🚀 Installing system dependencies for macOS..."
	@echo "This may take a while. Please be patient..."
	
	@echo "\n📦 Installing Homebrew packages..."
	brew install \
		inotify-tools \
		postgresql \
		pandoc \
		imagemagick \
		openjdk@17 \
		minio/stable/minio \
		asdf \
		rust || { echo "❌ Failed to install Homebrew packages. See error above."; exit 1; }
	
	@echo "\n📚 Installing MacTeX (this will take a while)..."
	brew install --cask mactex-no-gui || { echo "❌ Failed to install MacTeX. Try downloading from https://www.tug.org/mactex/"; exit 1; }
	
	@echo "\n📝 Installing Typst..."
	cargo install typst-cli --version $(REQUIRED_TYPST_VERSION) || { echo "❌ Failed to install Typst. Make sure Rust is properly installed."; exit 1; }
	
	@echo "\n⚙️ Configuring asdf..."
	echo -e "\n. $(brew --prefix asdf)/libexec/asdf.sh" >> ~/.zshrc
	. $(brew --prefix asdf)/libexec/asdf.sh
	
	@echo "\n💫 Installing Erlang and Elixir..."
	asdf plugin add erlang || true
	asdf plugin add elixir || true
	asdf install erlang $(REQUIRED_ERLANG_VERSION) || { echo "❌ Failed to install Erlang. Try running 'asdf install erlang $(REQUIRED_ERLANG_VERSION) -v' for verbose output."; exit 1; }
	asdf install elixir $(REQUIRED_ELIXIR_VERSION) || { echo "❌ Failed to install Elixir. Try running 'asdf install elixir $(REQUIRED_ELIXIR_VERSION) -v' for verbose output."; exit 1; }
	asdf global erlang $(REQUIRED_ERLANG_VERSION)
	asdf global elixir $(REQUIRED_ELIXIR_VERSION)
	
	@echo "\n✅ System dependencies installed successfully!"
	@echo "⚠️  Please restart your terminal for all changes to take effect."
	@echo "📝 Next steps:"
	@echo "  1. Run 'make check-versions' to verify installations"
	@echo "  2. Run 'make setup' to complete the setup process"

# Install system dependencies (for Windows)
install-deps-windows:
	@echo "🚀 Installing system dependencies for Windows..."
	@echo "This may take a while. Please be patient..."
	
	@echo "\n📦 Installing Chocolatey package manager..."
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" || { echo "❌ Failed to install Chocolatey"; exit 1; }
	
	@echo "\n📦 Installing system packages..."
	choco install -y `
		postgresql `
		pandoc `
		miktex `
		imagemagick `
		openjdk17 `
		git `
		rust `
		minio || { echo "❌ Failed to install system packages. See error above."; exit 1; }
	
	@echo "\n📝 Installing Typst..."
	cargo install typst-cli --version $(REQUIRED_TYPST_VERSION) || { echo "❌ Failed to install Typst. Make sure Rust is properly installed."; exit 1; }
	
	@echo "\n⚙️ Installing asdf-vm..."
	git clone https://github.com/asdf-vm/asdf-windows.git %USERPROFILE%\.asdf
	@powershell -NoProfile -Command "[System.Environment]::SetEnvironmentVariable('ASDF_DIR', '$env:USERPROFILE\.asdf', 'User')"
	@powershell -NoProfile -Command "[System.Environment]::SetEnvironmentVariable('Path', [System.Environment]::GetEnvironmentVariable('Path', 'User') + ';%ASDF_DIR%\bin', 'User')"
	
	@echo "\n💫 Installing Erlang and Elixir..."
	asdf plugin add erlang || true
	asdf plugin add elixir || true
	asdf install erlang $(REQUIRED_ERLANG_VERSION) || { echo "❌ Failed to install Erlang. Try running 'asdf install erlang $(REQUIRED_ERLANG_VERSION) -v' for verbose output."; exit 1; }
	asdf install elixir $(REQUIRED_ELIXIR_VERSION) || { echo "❌ Failed to install Elixir. Try running 'asdf install elixir $(REQUIRED_ELIXIR_VERSION) -v' for verbose output."; exit 1; }
	asdf global erlang $(REQUIRED_ERLANG_VERSION)
	asdf global elixir $(REQUIRED_ELIXIR_VERSION)
	
	@echo "\n✅ System dependencies installed successfully!"
	@echo "⚠️  Please restart your terminal for all changes to take effect."
	@echo "📝 Next steps:"
	@echo "  1. Run 'make check-versions' to verify installations"
	@echo "  2. Run 'make setup' to complete the setup process"

# Troubleshooting target
troubleshoot:
	@echo "🔍 Running troubleshooting checks..."
	
	@echo "\n📋 System Information:"
	@echo "Operating System: $(DETECTED_OS)"
	@echo "Shell: $(SHELL)"
	
	@echo "\n🔍 Checking PATH..."
	@echo "$$PATH"
	
	@echo "\n📦 Checking package managers..."
ifeq ($(DETECTED_OS),windows)
	@where choco || echo "❌ Chocolatey not found"
else ifeq ($(DETECTED_OS),macos)
	@which brew || echo "❌ Homebrew not found"
else
	@which apt || echo "❌ apt not found"
endif
	
	@echo "\n🔧 Checking build tools..."
	@which make || echo "❌ make not found"
	@which git || echo "❌ git not found"
	
	@echo "\n💻 Checking development tools..."
	@which elixir || echo "❌ elixir not found"
	@which erl || echo "❌ erlang not found"
	@which postgres || echo "❌ postgres not found"
	@which pandoc || echo "❌ pandoc not found"
	@which java || echo "❌ java not found"
	@which rustc || echo "❌ rust not found"
	
	@echo "\n📝 Common Issues and Solutions:"
	@echo "1. PATH issues:"
	@echo "   - Restart your terminal"
	@echo "   - Check your shell configuration (.bashrc, .zshrc, etc.)"
	@echo "2. Permission errors:"
	@echo "   - Run with sudo (Linux/macOS)"
	@echo "   - Run as Administrator (Windows)"
	@echo "3. Version mismatches:"
	@echo "   - Run 'make check-versions' for detailed version info"
	@echo "4. Installation failures:"
	@echo "   - Check internet connection"
	@echo "   - Clear package manager cache"
	@echo "   - Check disk space"
	
	@echo "\n💡 For more help:"
	@echo "  - Check the project documentation"
	@echo "  - Run 'make help' for available commands"
	@echo "  - Submit an issue on GitHub"

# Check environment file
check-env:
	@echo "🔍 Checking environment configuration..."
	@test -f $(ENV_FILE) || { echo "❌ $(ENV_FILE) file not found"; echo "💡 Tip: Copy .env.example to .env and update the values."; exit 1; }
	@echo "✅ Environment file exists"

# Check dependency versions
check-versions:
	@echo "Checking dependency versions..."
	
	@echo "\nChecking Elixir/Erlang..."
	@command -v elixir >/dev/null 2>&1 || { echo "❌ Elixir not installed"; exit 1; }
	@elixir --version | grep -q $(REQUIRED_ELIXIR_VERSION) || { echo "❌ Elixir $(REQUIRED_ELIXIR_VERSION) required"; exit 1; }
	@erl -eval '{ok, Version} = file:read_file(filename:join([code:root_dir(), "releases", erlang:system_info(otp_release), "OTP_VERSION"])), io:fwrite(Version), halt().' -noshell | grep -q $(REQUIRED_ERLANG_VERSION) || { echo "❌ Erlang/OTP $(REQUIRED_ERLANG_VERSION) required"; exit 1; }
	@echo "✅ Elixir/Erlang versions OK"
	
	@echo "\nChecking PostgreSQL..."
	@if command -v docker >/dev/null 2>&1; then \
		if docker ps | grep -q postgres; then \
			echo "✅ PostgreSQL running in Docker"; \
		else \
			if command -v postgres >/dev/null 2>&1; then \
				echo "✅ PostgreSQL installed locally"; \
			else \
				echo "⚠️  PostgreSQL not found locally or in Docker. Please ensure PostgreSQL is running:"; \
				echo "   - Run 'make docker-up' to start PostgreSQL in Docker"; \
				echo "   - Or install PostgreSQL locally using your package manager"; \
				exit 1; \
			fi \
		fi \
	else \
		if command -v postgres >/dev/null 2>&1; then \
			echo "✅ PostgreSQL installed locally"; \
		else \
			echo "⚠️  PostgreSQL not found and Docker not available."; \
			echo "Please install either Docker or PostgreSQL locally."; \
			exit 1; \
		fi \
	fi
	
	@echo "\nChecking MinIO..."
	@if command -v docker >/dev/null 2>&1; then \
		if docker ps | grep -q minio; then \
			echo "✅ MinIO running in Docker"; \
		else \
			if command -v minio >/dev/null 2>&1; then \
				echo "✅ MinIO installed locally"; \
			else \
				echo "⚠️  MinIO not found locally or in Docker. Please ensure MinIO is running:"; \
				echo "   - Run 'make docker-up' to start MinIO in Docker"; \
				echo "   - Or install MinIO locally using your package manager"; \
				exit 1; \
			fi \
		fi \
	else \
		if command -v minio >/dev/null 2>&1; then \
			echo "✅ MinIO installed locally"; \
		else \
			echo "⚠️  MinIO not found and Docker not available."; \
			echo "Please install either Docker or MinIO locally."; \
			exit 1; \
		fi \
	fi
	
	@echo "\nChecking Pandoc..."
	@command -v pandoc >/dev/null 2>&1 || { echo "❌ Pandoc not installed"; exit 1; }
	@pandoc --version | grep -q $(REQUIRED_PANDOC_VERSION) || { echo "❌ Pandoc $(REQUIRED_PANDOC_VERSION) required"; exit 1; }
	@echo "✅ Pandoc version OK"
	
	@echo "\nChecking ImageMagick..."
	@command -v convert >/dev/null 2>&1 || { echo "❌ ImageMagick not installed"; exit 1; }
	@echo "✅ ImageMagick installed"
	
	@echo "\nChecking LaTeX..."
	@command -v pdflatex >/dev/null 2>&1 || { echo "❌ LaTeX not installed"; exit 1; }
	@echo "✅ LaTeX installed"
	
	@echo "\nChecking Typst..."
	@command -v typst >/dev/null 2>&1 || { echo "❌ Typst not installed"; exit 1; }
	@typst --version | grep -q $(REQUIRED_TYPST_VERSION) || { echo "❌ Typst $(REQUIRED_TYPST_VERSION) required"; exit 1; }
	@echo "✅ Typst version OK"
	
	@echo "\nChecking Java..."
	@command -v java >/dev/null 2>&1 || { echo "❌ Java not installed"; exit 1; }
	@java -version 2>&1 | grep -q "version \"$(REQUIRED_JAVA_VERSION)" || \
	java -version 2>&1 | grep -q "version \"1.$(REQUIRED_JAVA_VERSION)" || \
	java -version 2>&1 | grep -q "openjdk version \"$(REQUIRED_JAVA_VERSION)" || \
	java -version 2>&1 | grep -q "openjdk version \"1.$(REQUIRED_JAVA_VERSION)" || \
	{ echo "⚠️  Java $(REQUIRED_JAVA_VERSION) recommended, but continuing with current version:"; \
	  java -version 2>&1 | head -1; \
	  echo "💡 If you encounter issues, consider upgrading to Java $(REQUIRED_JAVA_VERSION)"; \
	}
	@echo "✅ Java installed"
	
	@echo "\nChecking Rust toolchain..."
	@command -v rustc >/dev/null 2>&1 || { echo "❌ Rust not installed"; exit 1; }
	@echo "✅ Rust toolchain installed"
	
	@echo "\n✅ All dependency versions verified successfully!"

# Check Docker services
check-docker:
	@echo "🔍 Checking Docker services..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ Docker not installed"; exit 1; }
	@docker ps >/dev/null 2>&1 || { echo "❌ Docker daemon not running"; exit 1; }
	@echo "✅ Docker is running"
	
	@echo "\nChecking required services:"
	@if docker ps | grep -q postgres; then \
		echo "✅ PostgreSQL is running in Docker"; \
	else \
		echo "⚠️  PostgreSQL container not found"; \
	fi
	
	@if docker ps | grep -q minio; then \
		echo "✅ MinIO is running in Docker"; \
	else \
		echo "⚠️  MinIO container not found"; \
	fi
	
	@echo "\n💡 To start all services:"
	@echo "  make docker-up    - Start all Docker containers"
	@echo "  make docker-down  - Stop all Docker containers"

# Help target
help:
	@echo "Available targets:"
	@echo "  setup         - Set up the development environment"
	@echo "  deps          - Install Elixir dependencies"
	@echo "  check-deps    - Check system dependencies (PostgreSQL, MinIO)"
	@echo "  check-env     - Verify environment file exists"
	@echo "  check-versions- Check dependency versions"
	@echo "  check-docker  - Check Docker services status"
	@echo "  db            - Set up the database"
	@echo "  run           - Run the Wraft application"
	@echo "  test          - Run tests"
	@echo "  docker-up     - Start Docker containers"
	@echo "  docker-down   - Stop Docker containers"
	@echo "  install-deps  - Install system dependencies (auto-detects OS)"
	@echo "  install-deps-ubuntu - Install system dependencies for Ubuntu"
	@echo "  install-deps-macos  - Install system dependencies for macOS"
	@echo "  install-deps-windows- Install system dependencies for Windows"
	@echo "  troubleshoot  - Run diagnostics and show common solutions"
	@echo "  help          - Show this help message"