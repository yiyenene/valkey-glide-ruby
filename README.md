# Valkey

A Ruby client library for [Valkey][valkey-home] built with [Valkey Glide Core][valkey-glide-home] that tries to provide a drop in replacement for redis-rb.

## Getting started

Install with:

```
$ gem install valkey
```

You can connect to Valkey by instantiating the `Valkey` class:

```ruby
require "valkey"

valkey = Valkey.new

valkey.set("mykey", "hello world")
# => "OK"

valkey.get("mykey")
# => "hello world"
```

## Development with Docker

### Prerequisites

- Docker and Docker Compose

### Quick Start

Start the development environment with Valkey standalone server:

```bash
# Build and start containers
docker compose up -d

# Access the Ruby development container
docker compose exec app bash

# Inside the container, run tests
bundle exec rake test
```

### Running Tests

```bash
# Run all default tests (standalone mode)
docker compose exec app bundle exec rake test

# Run specific test groups
docker compose exec app bundle exec rake test:valkey

# Run with verbose output
docker compose exec app bundle exec rake test VERBOSE=1
```

### Cluster Mode (Optional)

To test cluster-specific features, start the cluster profile:

```bash
# Start with cluster (6 nodes on ports 7000-7005)
docker compose --profile cluster up -d

# Wait for cluster initialization to complete
docker compose logs cluster-init

# Run cluster tests
docker compose exec app bundle exec rake test:cluster
```

#### Testing with Different Valkey Versions

You can test with different Valkey versions by setting the `VALKEY_VERSION` environment variable:

```bash
# Test with Valkey 7
VALKEY_VERSION=7 docker compose --profile cluster up -d

# Test with Valkey 8
VALKEY_VERSION=8 docker compose --profile cluster up -d

# Test with Valkey 9 (default)
VALKEY_VERSION=9 docker compose --profile cluster up -d
# or simply
docker compose --profile cluster up -d
```

### Stopping Services

```bash
# Stop all services
docker compose down

# Stop and remove volumes
docker compose down -v
```

### Development Workflow

1. Start the environment: `docker compose up -d`
2. Make changes to your code (files are mounted from host)
3. Run tests: `docker compose exec app bundle exec rake test`
4. Debug: `docker compose exec app bash` and use Ruby debugger
5. Stop when done: `docker compose down`

### Rebuilding After Dependency Changes

If you modify `Gemfile` or `Gemfile.lock`:

```bash
docker compose build app
docker compose up -d
```

## Building the FFI

This library uses [Valkey Glide Core][valkey-glide-home] (Rust) via FFI (Foreign Function Interface). The Rust library is managed as a Git submodule.

### Initial Setup

Clone the repository with submodules:

```bash
# If you already cloned without submodules
git submodule update --init --recursive

# Or clone with submodules from the start
git clone --recursive https://github.com/valkey-io/valkey-glide-ruby.git
```

Create `.env` file from the template:

```bash
cp .env.example .env
```

This sets up the `GLIDE_VERSION` environment variable for FFI builds.

### Building FFI Library

The FFI library (`libglide_ffi.so`) is built using a Docker multi-stage build:

```bash
# Using the build script (recommended)
./bin/build-ffi

# Or manually with Docker Compose
docker compose --profile build run --rm ffi-builder
# Then copy the built library
cp glide/ffi/target/release/libglide_ffi.so lib/valkey/
```

### Updating Valkey Glide Submodule

To update the submodule to the latest release:

```bash
# Using the update script (automatically updates .env with version)
./bin/update-glide

# Then commit the changes
git commit -m "Update glide submodule to latest release"
```

The script automatically updates the `.env` file with the new `GLIDE_VERSION`. 

If you need to manually set a specific version, edit `.env`:

```bash
echo "GLIDE_VERSION=2.2.0" > .env
```

### Cleaning Build Artifacts

```bash
# Clean build artifacts
bundle exec rake ffi:clean

# Or manually remove
rm -rf glide/ffi/target/
```

### Architecture

- **Builder Stage**: Compiles Rust code in a Rust-enabled Docker image
- **Runtime Stage**: Lightweight Ruby image with pre-built FFI library
- **Caching**: Separate volumes for Rust and Ruby dependencies for faster builds

Checkout [the implementation status of the Valkey commands][commands-implementation-progress].


[valkey-home]: https://valkey.io
[valkey-glide-home]: https://github.com/valkey-io/valkey-glide
[commands-implementation-progress]: https://github.com/valkey-io/valkey-glide-ruby/wiki/The-implementation-status-of-the-Valkey-commands

