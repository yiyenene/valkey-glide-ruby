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

Checkout [the implementation status of the Valkey commands][commands-implementation-progress].


[valkey-home]: https://valkey.io
[valkey-glide-home]: https://github.com/valkey-io/valkey-glide
[commands-implementation-progress]: https://github.com/valkey-io/valkey-glide-ruby/wiki/The-implementation-status-of-the-Valkey-commands

