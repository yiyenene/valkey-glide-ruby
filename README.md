# Valkey

Valkey gem is based on redis-rb and provides a Ruby client for Valkey

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
