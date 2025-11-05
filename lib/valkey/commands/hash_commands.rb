# frozen_string_literal: true

class Valkey
  module Commands
    # This module contains commands on the Hash data type.
    #
    # @see https://valkey.io/commands/#hash
    #
    module HashCommands
      # Get the number of fields in a hash.
      #
      # @param [String] key
      # @return [Integer] number of fields in the hash
      def hlen(key)
        send_command(RequestType::HLEN, [key])
      end

      # Set one or more hash values.
      #
      # @example
      #   valkey.hset("hash", "f1", "v1", "f2", "v2") # => 2
      #   valkey.hset("hash", { "f1" => "v1", "f2" => "v2" }) # => 2
      #
      # @param [String] key
      # @param [Array<String> | Hash<String, String>] attrs array or hash of fields and values
      # @return [Integer] The number of fields that were added to the hash
      def hset(key, *attrs)
        attrs = attrs.first.flatten if attrs.size == 1 && attrs.first.is_a?(Hash)

        send_command(RequestType::HSET, [key, *attrs])
      end

      # Set the value of a hash field, only if the field does not exist.
      #
      # @param [String] key
      # @param [String] field
      # @param [String] value
      # @return [Boolean] whether or not the field was **added** to the hash
      def hsetnx(key, field, value)
        send_command(RequestType::HSET_NX, [key, field, value])
      end

      # Set one or more hash values.
      #
      # @example
      #   valkey.hmset("hash", "f1", "v1", "f2", "v2")
      #     # => "OK"
      #
      # @param [String] key
      # @param [Array<String>] attrs array of fields and values
      # @return [String] `"OK"`
      #
      # @see #mapped_hmset
      def hmset(key, *attrs)
        send_command(RequestType::HMSET, [key] + attrs)
      end

      # Set one or more hash values.
      #
      # @example
      #   valkey.mapped_hmset("hash", { "f1" => "v1", "f2" => "v2" })
      #     # => "OK"
      #
      # @param [String] key
      # @param [Hash] hash a non-empty hash with fields mapping to values
      # @return [String] `"OK"`
      #
      # @see #hmset
      def mapped_hmset(key, hash)
        hmset(key, *hash.flatten)
      end

      # Get the value of a hash field.
      #
      # @param [String] key
      # @param [String] field
      # @return [String]
      def hget(key, field)
        send_command(RequestType::HGET, [key, field])
      end

      # Get the values of all the given hash fields.
      #
      # @example
      #   valkey.hmget("hash", "f1", "f2")
      #     # => ["v1", "v2"]
      #
      # @param [String] key
      # @param [Array<String>] fields array of fields
      # @return [Array<String>] an array of values for the specified fields
      #
      # @see #mapped_hmget
      def hmget(key, *fields, &blk)
        fields.flatten!(1)
        send_command(RequestType::HMGET, [key] + fields, &blk)
      end

      # Get the values of all the given hash fields.
      #
      # @example
      #   valkey.mapped_hmget("hash", "f1", "f2")
      #     # => { "f1" => "v1", "f2" => "v2" }
      #
      # @param [String] key
      # @param [Array<String>] fields array of fields
      # @return [Hash] a hash mapping the specified fields to their values
      #
      # @see #hmget
      def mapped_hmget(key, *fields)
        fields.flatten!(1)
        hmget(key, fields) do |reply|
          if reply.is_a?(Array)
            Hash[fields.zip(reply)]
          else
            reply
          end
        end
      end

      # Get one or more random fields from a hash.
      #
      # @example Get one random field
      #   valkey.hrandfield("hash")
      #     # => "f1"
      # @example Get multiple random fields
      #   valkey.hrandfield("hash", 2)
      #     # => ["f1, "f2"]
      # @example Get multiple random fields with values
      #   valkey.hrandfield("hash", 2, with_values: true)
      #     # => [["f1", "s1"], ["f2", "s2"]]
      #
      # @param [String] key
      # @param [Integer] count
      # @param [Hash] options
      #   - `:with_values => true`: include values in output
      #
      # @return [nil, String, Array<String>, Array<[String, Float]>]
      #   - when `key` does not exist, `nil`
      #   - when `count` is not specified, a field name
      #   - when `count` is specified and `:with_values` is not specified, an array of field names
      #   - when `:with_values` is specified, an array with `[field, value]` pairs
      def hrandfield(key, count = nil, withvalues: false, with_values: withvalues)
        if with_values && count.nil?
          raise ArgumentError, "count argument must be specified"
        end

        args = [key]
        args << count if count
        args << "WITHVALUES" if with_values

        send_command(RequestType::HRAND_FIELD, args)
      end

      # Delete one or more hash fields.
      #
      # @param [String] key
      # @param [String, Array<String>] field
      # @return [Integer] the number of fields that were removed from the hash
      def hdel(key, *fields)
        fields.flatten!(1)
        send_command(RequestType::HDEL, [key] + fields)
      end

      # Determine if a hash field exists.
      #
      # @param [String] key
      # @param [String] field
      # @return [Boolean] whether or not the field exists in the hash
      def hexists(key, field)
        send_command(RequestType::HEXISTS, [key, field])
      end

      # Increment the integer value of a hash field by the given integer number.
      #
      # @param [String] key
      # @param [String] field
      # @param [Integer] increment
      # @return [Integer] value of the field after incrementing it
      def hincrby(key, field, increment)
        send_command(RequestType::HINCR_BY, [key, field, Integer(increment)])
      end

      # Increment the numeric value of a hash field by the given float number.
      #
      # @param [String] key
      # @param [String] field
      # @param [Float] increment
      # @return [Float] value of the field after incrementing it
      def hincrbyfloat(key, field, increment)
        send_command(RequestType::HINCR_BY_FLOAT, [key, field, Float(increment)])
      end

      # Get all the fields in a hash.
      #
      # @param [String] key
      # @return [Array<String>]
      def hkeys(key)
        send_command(RequestType::HKEYS, [key])
      end

      # Get all the values in a hash.
      #
      # @param [String] key
      # @return [Array<String>]
      def hvals(key)
        send_command(RequestType::HVALS, [key])
      end

      # Get all the fields and values in a hash.
      #
      # @param [String] key
      # @return [Hash<String, String>]
      def hgetall(key)
        send_command(RequestType::HGET_ALL, [key])
      end

      # Get the length of a hash field's value.
      #
      # @param [String] key
      # @param [String] field
      # @return [Integer] the length of the field value, or 0 if the field does not exist
      def hstrlen(key, field)
        send_command(RequestType::HSTRLEN, [key, field])
      end

      # Scan a hash
      #
      # @example Retrieve the first batch of key/value pairs in a hash
      #   valkey.hscan("hash", 0)
      #
      # @param [String] key
      # @param [String, Integer] cursor the cursor of the iteration
      # @param [Hash] options
      #   - `:match => String`: only return keys matching the pattern
      #   - `:count => Integer`: return count keys at most per iteration
      #
      # @return [String, Array<[String, String]>] the next cursor and all found keys
      #
      # See the [Valkey Server HSCAN documentation](https://valkey.io/commands/hscan/) for further details
      def hscan(key, cursor, match: nil, count: nil)
        args = [key, cursor.to_s]
        args << "MATCH" << match if match
        args << "COUNT" << count if count

        send_command(RequestType::HSCAN, args) do |reply|
          [reply[0], reply[1].each_slice(2).to_a]
        end
      end

      # Scan a hash
      #
      # @example Retrieve all of the key/value pairs in a hash
      #   valkey.hscan_each("hash").to_a
      #   # => [["key70", "70"], ["key80", "80"]]
      #
      # @param [String] key
      # @param [Hash] options
      #   - `:match => String`: only return keys matching the pattern
      #   - `:count => Integer`: return count keys at most per iteration
      #
      # @return [Enumerator] an enumerator for all found keys
      #
      # See the [Valkey Server HSCAN documentation](https://valkey.io/commands/hscan/) for further details
      def hscan_each(key, match: nil, count: nil, &block)
        return to_enum(:hscan_each, key, match: match, count: count) unless block_given?

        cursor = 0
        loop do
          cursor, values = hscan(key, cursor, match: match, count: count)
          values.each(&block)
          break if cursor == "0"
        end
      end

      # Sets the time to live in seconds for one or more fields.
      #
      # @example
      #   valkey.hset("hash", "f1", "v1")
      #   valkey.hexpire("hash", 10, "f1", "f2") # => [1, -2]
      #
      # @param [String] key
      # @param [Integer] ttl
      # @param [Array<String>] fields
      # @return [Array<Integer>] Feedback on if the fields have been updated.
      #
      # See https://valkey.io/commands/hexpire/#return-information for array reply.
      def hexpire(key, ttl, *fields)
        send_command(RequestType::HEXPIRE, [key, ttl, "FIELDS", fields.length, *fields])
      end

      # Returns the time to live in seconds for one or more fields.
      #
      # @example
      #   valkey.hset("hash", "f1", "v1", "f2", "v2")
      #   valkey.hexpire("hash", 10, "f1") # => [1]
      #   valkey.httl("hash", "f1", "f2", "f3") # => [10, -1, -2]
      #
      # @param [String] key
      # @param [Array<String>] fields
      # @return [Array<Integer>] Feedback on the TTL of the fields.
      #
      # See https://valkey.io/commands/httl/#return-information for array reply.
      def httl(key, *fields)
        send_command(RequestType::HTTL, [key, "FIELDS", fields.length, *fields])
      end
    end
  end
end

