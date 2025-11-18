# frozen_string_literal: true

module Helper
  module Generic
    include Helper

    attr_reader :log, :valkey

    alias r valkey

    def run
      if respond_to?(:around)
        around { super }
      else
        super
      end
    end

    def silent
      verbose = $VERBOSE
      $VERBOSE = false

      begin
        yield
      ensure
        $VERBOSE = verbose
      end
    end

    def setup
      @valkey = init _new_client

      # Run GC to make sure orphaned connections are closed.
      GC.start
      super
    end

    def teardown
      valkey&.close
      super
    end

    def assert_in_range(range, value)
      assert range.include?(value), "expected #{value} to be in #{range.inspect}"
    end

    def target_version(target)
      if version < target
        skip("Requires Valkey > #{target}") if respond_to?(:skip)
      else
        yield
      end
    end

    def keys(pattern = "*")
      list = []

      loop do
        cursor, keys = r.scan(0, match: pattern, count: 100)
        list.concat(keys)
        break if cursor == "0"
      end

      list
    end

    def all_keys
      keys.sort
    end

    def with_db(index)
      r.select(index)
      yield
    end

    def omit_version(min_ver)
      skip("Requires Valkey > #{min_ver}") if version < min_ver
    end

    def version
      Version.new(valkey.info["valkey_version"])
    end

    def with_acl
      admin = _new_client
      admin.acl("SETUSER", "johndoe", "on",
                "+ping", "+select", "+command", "+cluster|slots", "+cluster|nodes", "+readonly",
                ">mysecret")
      yield("johndoe", "mysecret")
    ensure
      admin.acl("DELUSER", "johndoe")
      admin.close
    end

    def with_default_user_password
      admin = _new_client
      admin.acl("SETUSER", "default", ">mysecret")
      yield("default", "mysecret")
    ensure
      admin.acl("SETUSER", "default", "nopass")
      admin.close
    end

    # Simple class to control retry behavior from within a block
    class RetryDecision
      attr_accessor :should_retry

      def initialize
        @should_retry = false
      end

      # Mark that the operation should be retried
      def retry!
        @should_retry = true
      end
    end

    # Retry a block with flexible retry conditions
    #
    # @param max_retries [Integer] maximum number of retries
    # @param sleep_time [Float] seconds to sleep between retries
    # @param rescue_errors [Class, Array<Class>] exception class(es) to rescue and retry
    # @yield [retry_decision] block to execute, receives RetryDecision object
    # @return [Array] [result, retry_count]
    #
    # @example Retry on empty result
    #   result, count = retry_with(max_retries: 3, sleep_time: 0.5) do |retry_decision|
    #     res = some_operation
    #     retry_decision.retry! if res.empty?
    #     res
    #   end
    #
    # @example Retry on timeout exception (single error)
    #   result, count = retry_with(max_retries: 2, rescue_errors: Valkey::TimeoutError) do
    #     some_operation_that_may_timeout
    #   end
    #
    # @example Retry on multiple exceptions
    #   result, count = retry_with(rescue_errors: [Valkey::TimeoutError, Valkey::ConnectionError]) do
    #     some_operation
    #   end
    #
    def retry_with(max_retries: 3, sleep_time: 0.5, rescue_errors: [])
      # Allow single error class or array of error classes
      rescue_errors = Array(rescue_errors)

      retry_count = 0
      result = nil

      begin
        loop do
          decision = RetryDecision.new
          result = yield(decision)

          break if !decision.should_retry || retry_count >= max_retries

          retry_count += 1
          sleep sleep_time
        end

        [result, retry_count]
      rescue *rescue_errors => e
        raise e if retry_count >= max_retries

        retry_count += 1
        sleep sleep_time
        retry
      end
    end
  end
end
