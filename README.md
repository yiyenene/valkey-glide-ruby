# Valkey

A Ruby client library for Valkey built with [Valkey Glide Core][valkey-glide-home] that tries to provide a drop in replacement for redis-rb.

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


[valkey-glide-home]: https://github.com/valkey-io/valkey-glide
