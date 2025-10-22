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

        send_command(request, args)
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

      # Removes one or multiple entries from the pending entries list of a stream consumer group.
      #
      # @example With a entry id
      #   valkey.xack('mystream', 'mygroup', '1526569495631-0')
      # @example With splatted entry ids
      #   valkey.xack('mystream', 'mygroup', '0-1', '0-2')
      # @example With arrayed entry ids
      #   valkey.xack('mystream', 'mygroup', %w[0-1 0-2])
      #
      # @param key   [String]        the stream key
      # @param group [String]        the consumer group name
      # @param ids   [Array<String>] one or multiple entry ids
      #
      # @return [Integer] the number of entries successfully acknowledged
      def xack(key, group, *ids)
        # To keep compatibility with Redis
        raise TypeError, "key cannot be nil" if key.nil?
        raise TypeError, "group cannot be nil" if group.nil?

        args = [key, group].concat(ids.flatten)
        send_command(RequestType::X_ACK, args)
      end

      # Changes the ownership of a pending entry
      #
      # @example With splatted entry ids
      #   valkey.xclaim('mystream', 'mygroup', 'consumer1', 3600000, '0-1', '0-2')
      # @example With arrayed entry ids
      #   valkey.xclaim('mystream', 'mygroup', 'consumer1', 3600000, %w[0-1 0-2])
      # @example With idle option
      #   valkey.xclaim('mystream', 'mygroup', 'consumer1', 3600000, %w[0-1 0-2], idle: 1000)
      # @example With time option
      #   valkey.xclaim('mystream', 'mygroup', 'consumer1', 3600000, %w[0-1 0-2], time: 1542866959000)
      # @example With retrycount option
      #   valkey.xclaim('mystream', 'mygroup', 'consumer1', 3600000, %w[0-1 0-2], retrycount: 10)
      # @example With force option
      #   valkey.xclaim('mystream', 'mygroup', 'consumer1', 3600000, %w[0-1 0-2], force: true)
      # @example With justid option
      #   valkey.xclaim('mystream', 'mygroup', 'consumer1', 3600000, %w[0-1 0-2], justid: true)
      #
      # @param key           [String]        the stream key
      # @param group         [String]        the consumer group name
      # @param consumer      [String]        the consumer name
      # @param min_idle_time [Integer]       the number of milliseconds
      # @param ids           [Array<String>] one or multiple entry ids
      # @param opts          [Hash]          several options for `XCLAIM` command
      #
      # @option opts [Integer] :idle       the number of milliseconds as last time it was delivered of the entry
      # @option opts [Integer] :time       the number of milliseconds as a specific Unix Epoch time
      # @option opts [Integer] :retrycount the number of retry counter
      # @option opts [Boolean] :force      whether to create the pending entry to the pending entries list or not
      # @option opts [Boolean] :justid     whether to fetch just an array of entry ids or not
      #
      # @return [Hash{String => Hash}] the entries successfully claimed
      # @return [Array<String>]        the entry ids successfully claimed if justid option is `true`
      def xclaim(key, group, consumer, min_idle_time, *ids, **opts)
        # To keep compatibility with Redis
        raise TypeError, "key cannot be nil" if key.nil?
        raise TypeError, "group cannot be nil" if group.nil?

        args = [key, group, consumer, min_idle_time].concat(ids.flatten)
        args.concat(['IDLE',       opts[:idle].to_i])  if opts[:idle]
        args.concat(['TIME',       opts[:time].to_i])  if opts[:time]
        args.concat(['RETRYCOUNT', opts[:retrycount]]) if opts[:retrycount]
        args << 'FORCE'                                if opts[:force]
        args << 'JUSTID'                               if opts[:justid]
        blk = opts[:justid] ? Utils::Noop : Utils::HashifyStreamEntries
        send_command(RequestType::X_CLAIM, args, &blk)
      end

      # Transfers ownership of pending stream entries that match the specified criteria.
      #
      # @example Claim next pending message stuck > 5 minutes  and mark as retry
      #   valkey.xautoclaim('mystream', 'mygroup', 'consumer1', 3600000, '0-0')
      # @example Claim 50 next pending messages stuck > 5 minutes  and mark as retry
      #   valkey.xautoclaim('mystream', 'mygroup', 'consumer1', 3600000, '0-0', count: 50)
      # @example Claim next pending message stuck > 5 minutes and don't mark as retry
      #   valkey.xautoclaim('mystream', 'mygroup', 'consumer1', 3600000, '0-0', justid: true)
      # @example Claim next pending message after this id stuck > 5 minutes  and mark as retry
      #   redis.xautoclaim('mystream', 'mygroup', 'consumer1', 3600000, '1641321233-0')
      #
      # @param key           [String]        the stream key
      # @param group         [String]        the consumer group name
      # @param consumer      [String]        the consumer name
      # @param min_idle_time [Integer]       the number of milliseconds
      # @param start         [String]        entry id to start scanning from or 0-0 for everything
      # @param count         [Integer]       number of messages to claim (default 1)
      # @param justid        [Boolean]       whether to fetch just an array of entry ids or not.
      #                                      Does not increment retry count when true
      #
      # @return [Hash{String => Hash}] the entries successfully claimed
      # @return [Array<String>]        the entry ids successfully claimed if justid option is `true`
      def xautoclaim(key, group, consumer, min_idle_time, start, count: nil, justid: false)
        args = [key, group, consumer, min_idle_time, start]
        if count
          args << 'COUNT'
          args << count.to_s
        end
        args << 'JUSTID' if justid
        blk = justid ? Utils::HashifyStreamAutoclaimJustId : Utils::HashifyStreamAutoclaim
        send_command(RequestType::X_AUTO_CLAIM, args, &blk)
      end

      # Fetches not acknowledging pending entries
      #
      # @example With key and group
      #   valkey.xpending('mystream', 'mygroup')
      # @example With range options
      #   valkey.xpending('mystream', 'mygroup', '-', '+', 10)
      # @example With range and idle time options
      #   valkey.xpending('mystream', 'mygroup', '-', '+', 10, idle: 9000)
      # @example With range and consumer options
      #   valkey.xpending('mystream', 'mygroup', '-', '+', 10, 'consumer1')
      #
      # @param key      [String]  the stream key
      # @param group    [String]  the consumer group name
      # @param start    [String]  start first entry id of range
      # @param end      [String]  end   last entry id of range
      # @param count    [Integer] count the number of entries as limit
      # @param consumer [String]  the consumer name
      #
      # @option opts [Integer] :idle       pending message minimum idle time in milliseconds
      #
      # @return [Hash]        the summary of pending entries
      # @return [Array<Hash>] the pending entries details if options were specified
      def xpending(key, group, *args, idle: nil)
        command_args = [key, group]
        command_args << 'IDLE' << Integer(idle) if idle
        case args.size
        when 0, 3, 4
          command_args.concat(args)
        else
          raise ArgumentError, "wrong number of arguments (given #{args.size + 2}, expected 2, 5 or 6)"
        end

        summary_needed = args.empty?
        blk = summary_needed ? Utils::HashifyStreamPendings : Utils::HashifyStreamPendingDetails
        send_command(RequestType::X_PENDING, command_args, &blk)
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
