# frozen_string_literal: true

class Valkey
  module Commands
    # This module contains commands on the Stream data type.
    #
    # @see https://valkey.io/commands/#stream
    #
    module StreamCommands
      # Returns the stream information each subcommand.
      #
      # @example stream
      #   valkey.xinfo('stream', 'my-stream')
      # @example groups
      #   valkey.xinfo('groups', 'my-stream')
      # @example consumers
      #   valkey.xinfo('consumers', 'my-stream', 'mygroup')
      #
      # @param subcommand [String] `stream` `groups` `consumers`
      # @param key        [String] the stream key
      # @param group      [String] the consumer group name, required if subcommand is `consumers`
      #
      # @return [Hash]        information of the stream if subcommand is `stream`
      # @return [Array<Hash>] information of the consumer groups if subcommand is `groups`
      # @return [Array<Hash>] information of the consumers if subcommand is `consumers`
      def xinfo(subcommand, key, group = nil)
        request =
          case subcommand.to_s.downcase
          when 'stream'
            RequestType::X_INFO_STREAM
          when 'groups'
            RequestType::X_INFO_GROUPS
          when 'consumers'
            RequestType::X_INFO_CONSUMERS
          else
            RequestType::INVALID_REQUEST
          end
        args = [key, group].compact

        send_command(request, args)
      end

      # Add new entry to the stream.
      #
      # @example Without options
      #   valkey.xadd('mystream', { f1: 'v1', f2: 'v2' })
      # @example With options
      #   valkey.xadd('mystream', { f1: 'v1', f2: 'v2' }, id: '0-0', maxlen: 1000, approximate: true, nomkstream: true)
      #
      # @param key   [String] the stream key
      # @param entry [Hash]   one or multiple field-value pairs
      # @param opts  [Hash]   several options for `XADD` command
      #
      # @option opts [String]  :id          the entry id, default value is `*`, it means auto generation
      # @option opts [Integer] :maxlen      max length of entries to keep
      # @option opts [Integer] :minid       min id of entries to keep
      # @option opts [Boolean] :approximate whether to add `~` modifier of maxlen/minid or not
      # @option opts [Boolean] :nomkstream  whether to add NOMKSTREAM, default is not to add
      #
      # @return [String] the entry id
      def xadd(key, entry, approximate: nil, maxlen: nil, minid: nil, nomkstream: nil, id: '*')
        args = [key]
        args << 'NOMKSTREAM' if nomkstream
        if maxlen
          raise ArgumentError, "can't supply both maxlen and minid" if minid

          args << "MAXLEN"
          args << "~" if approximate
          args << maxlen
        elsif minid
          args << "MINID"
          args << "~" if approximate
          args << minid
        end
        args << id
        args.concat(entry.flatten)

        send_command(RequestType::X_ADD, args)
      end

      # Trims older entries of the stream if needed.
      #
      # @example Without options
      #   valkey.xtrim('mystream', 1000)
      # @example With options
      #   valkey.xtrim('mystream', 1000, approximate: true)
      # @example With strategy
      #   valkey.xtrim('mystream', '1-0', strategy: 'MINID')
      #
      # @overload xtrim(key, maxlen, strategy: 'MAXLEN', approximate: true)
      #   @param key         [String]  the stream key
      #   @param maxlen      [Integer] max length of entries
      #   @param strategy    [String]  the limit strategy, must be MAXLEN
      #   @param approximate [Boolean] whether to add `~` modifier of maxlen or not
      #   @param limit       [Integer] maximum count of entries to be evicted
      # @overload xtrim(key, minid, strategy: 'MINID', approximate: true)
      #   @param key         [String]  the stream key
      #   @param minid       [String]  minimum id of entries
      #   @param strategy    [String]  the limit strategy, must be MINID
      #   @param approximate [Boolean] whether to add `~` modifier of minid or not
      #   @param limit       [Integer] maximum count of entries to be evicted
      #
      # @return [Integer] the number of entries actually deleted
      def xtrim(key, len_or_id, strategy: 'MAXLEN', approximate: false, limit: nil)
        strategy = strategy.to_s.upcase

        args = [key, strategy]
        args << '~' if approximate
        args << len_or_id
        args.concat(['LIMIT', limit]) if limit
        send_command(RequestType::X_TRIM, args)
      end

      # Delete entries by entry ids.
      #
      # @example With splatted entry ids
      #   valkey.xdel('mystream', '0-1', '0-2')
      # @example With arrayed entry ids
      #   valkey.xdel('mystream', ['0-1', '0-2'])
      #
      # @param key [String]        the stream key
      # @param ids [Array<String>] one or multiple entry ids
      #
      # @return [Integer] the number of entries actually deleted
      def xdel(key, *ids)
        # To keep compatibility with Redis
        raise TypeError, "key cannot be nil" if key.nil?

        args = [key].concat(ids.flatten)
        send_command(RequestType::X_DEL, args)
      end

      # Fetches entries of the stream in ascending order.
      #
      # @example Without options
      #   valkey.xrange('mystream')
      # @example With a specific start
      #   valkey.xrange('mystream', '0-1')
      # @example With a specific start and end
      #   valkey.xrange('mystream', '0-1', '0-3')
      # @example With count options
      #   valkey.xrange('mystream', count: 10)
      #
      # @param key [String]  the stream key
      # @param start [String]  first entry id of range, default value is `-`
      # @param end [String]  last entry id of range, default value is `+`
      # @param count [Integer] the number of entries as limit
      #
      # @return [Array<Array<String, Hash>>] the ids and entries pairs
      def xrange(key, start = '-', range_end = '+', count: nil)
        # To keep compatibility with Redis
        raise TypeError, "key cannot be nil" if key.nil?

        args = [key, start, range_end]
        args.concat(['COUNT', count]) if count
        send_command(RequestType::X_RANGE, args, &Utils::HashifyStreamEntries)
      end

      # Fetches entries of the stream in descending order.
      #
      # @example Without options
      #   valkey.xrevrange('mystream')
      # @example With a specific end
      #   valkey.xrevrange('mystream', '0-3')
      # @example With a specific end and start
      #   valkey.xrevrange('mystream', '0-3', '0-1')
      # @example With count options
      #   valkey.xrevrange('mystream', count: 10)
      #
      # @param key [String]  the stream key
      # @param end [String]  first entry id of range, default value is `+`
      # @param start [String]  last entry id of range, default value is `-`
      # @params count [Integer] the number of entries as limit
      #
      # @return [Array<Array<String, Hash>>] the ids and entries pairs
      def xrevrange(key, range_end = '+', start = '-', count: nil)
        # To keep compatibility with Redis
        raise TypeError, "key cannot be nil" if key.nil?

        args = [key, range_end, start]
        args.concat(['COUNT', count]) if count
        send_command(RequestType::X_REV_RANGE, args, &Utils::HashifyStreamEntries)
      end

      # Returns the number of entries inside a stream.
      #
      # @example With key
      #   valkey.xlen('mystream')
      #
      # @param key [String] the stream key
      #
      # @return [Integer] the number of entries
      def xlen(key)
        # To keep compatibility with Redis
        raise TypeError, "key cannot be nil" if key.nil?

        send_command(RequestType::X_LEN, [key])
      end

      # Fetches entries from one or multiple streams. Optionally blocking.
      #
      # @example With a key
      #   valkey.xread('mystream', '0-0')
      # @example With multiple keys
      #   valkey.xread(%w[mystream1 mystream2], %w[0-0 0-0])
      # @example With count option
      #   valkey.xread('mystream', '0-0', count: 2)
      # @example With block option
      #   valkey.xread('mystream', '$', block: 1000)
      #
      # @param keys  [Array<String>] one or multiple stream keys
      # @param ids   [Array<String>] one or multiple entry ids
      # @param count [Integer]       the number of entries as limit per stream
      # @param block [Integer]       the number of milliseconds as blocking timeout
      #
      # @return [Hash{String => Hash{String => Hash}}] the entries
      def xread(keys, ids, count: nil, block: nil)
        args = []
        args << 'COUNT' << count if count
        args << 'BLOCK' << block.to_i if block
        _xread(RequestType::X_READ, args, keys, ids, block)
      end

      # Manages the consumer group of the stream.
      #
      # @example With `create` subcommand
      #   valkey.xgroup(:create, 'mystream', 'mygroup', '$')
      # @example With `createconsumer` subcommand
      #   valkey.xgroup(:createconsumer, 'mystream', 'mygroup', 'consumer1')
      # @example With `setid` subcommand
      #   valkey.xgroup(:setid, 'mystream', 'mygroup', '$')
      # @example With `destroy` subcommand
      #   valkey.xgroup(:destroy, 'mystream', 'mygroup')
      # @example With `delconsumer` subcommand
      #   valkey.xgroup(:delconsumer, 'mystream', 'mygroup', 'consumer1')
      #
      # @param subcommand     [String] `create` `createconsumer` `setid` `destroy` `delconsumer`
      # @param key            [String] the stream key
      # @param group          [String] the consumer group name
      # @param id_or_consumer [String]
      #   * the entry id or `$`, required if subcommand is `create` or `setid`
      #   * the consumer name, required if subcommand is `delconsumer`
      # @param mkstream [Boolean] whether to create an empty stream automatically or not
      #
      # @return [String] `OK` if subcommand is `create` or `setid`
      # @return [Integer] effected count if subcommand is `createconsumer` or `destroy` or `delconsumer`
      def xgroup(subcommand, key, group, id_or_consumer = nil, mkstream: false)
        request =
          case subcommand.to_s.downcase
          when 'create'
            RequestType::X_GROUP_CREATE
          when 'createconsumer'
            RequestType::X_GROUP_CREATE_CONSUMER
          when 'delconsumer'
            RequestType::X_GROUP_DEL_CONSUMER
          when 'destroy'
            RequestType::X_GROUP_DESTROY
          when 'setid'
            RequestType::X_GROUP_SET_ID
          else
            RequestType::INVALID_REQUEST
          end
        args = [key, group, id_or_consumer, (mkstream ? 'MKSTREAM' : nil)].compact

        send_command(request, args) do |response|
          next response unless [RequestType::X_GROUP_CREATE_CONSUMER, RequestType::X_GROUP_DESTROY].include?(request)
          # Even though the document says it returns an Integer, I don't know why GLIDE returns a boolean
          # as a result of XGROUP CREATE_CONSUMER and XGROUP DESTROY.
          next 1 if response == true
          next 0 if response == false

          response
        end
      end

      # Fetches a subset of the entries from one or multiple streams related with the consumer group.
      # Optionally blocking.
      #
      # @example With a key
      #   valkey.xreadgroup('mygroup', 'consumer1', 'mystream', '>')
      # @example With multiple keys
      #   valkey.xreadgroup('mygroup', 'consumer1', %w[mystream1 mystream2], %w[> >])
      # @example With count option
      #   valkey.xreadgroup('mygroup', 'consumer1', 'mystream', '>', count: 2)
      # @example With block option
      #   valkey.xreadgroup('mygroup', 'consumer1', 'mystream', '>', block: 1000)
      # @example With noack option
      #   valkey.xreadgroup('mygroup', 'consumer1', 'mystream', '>', noack: true)
      #
      # @param group    [String]        the consumer group name
      # @param consumer [String]        the consumer name
      # @param keys     [Array<String>] one or multiple stream keys
      # @param ids      [Array<String>] one or multiple entry ids
      # @param opts     [Hash]          several options for `XREADGROUP` command
      #
      # @option opts [Integer] :count the number of entries as limit
      # @option opts [Integer] :block the number of milliseconds as blocking timeout
      # @option opts [Boolean] :noack whether message loss is acceptable or not
      #
      # @return [Hash{String => Hash{String => Hash}}] the entries
      def xreadgroup(group, consumer, keys, ids, count: nil, block: nil, noack: nil)
        args = ['GROUP', group, consumer]
        args << 'COUNT' << count if count
        args << 'BLOCK' << block.to_i if block
        args << 'NOACK' if noack
        _xread(RequestType::X_READ_GROUP, args, keys, ids, block)
      end

      private

      def _xread(request, args, keys, ids, _blocking_timeout_msec)
        keys = keys.is_a?(Array) ? keys : [keys]
        ids = ids.is_a?(Array) ? ids : [ids]
        args << 'STREAMS'
        args.concat(keys)
        args.concat(ids)

        # @todo reproduce the behavior of Redis
        send_command(request, args, &Utils::HashifyStreams)
      end
    end
  end
end
