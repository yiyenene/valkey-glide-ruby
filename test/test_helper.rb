# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "valkey"

require "minitest/autorun"

$VERBOSE = true

PORT        = 6381
DB          = 15
TIMEOUT     = Float(ENV["TIMEOUT"] || 1.0)
LOW_TIMEOUT = Float(ENV["LOW_TIMEOUT"] || 0.01) # for blocking-command tests
OPTIONS     = { port: PORT, db: DB, timeout: TIMEOUT }.freeze

Dir[File.expand_path("lint/**/*.rb", __dir__)].sort.each do |f|
  require f
end

module Helper
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

  class Version
    include Comparable

    attr_reader :parts

    def initialize(version)
      @parts = case version
               when Version
                 version.parts
               else
                 version.to_s.split(".")
               end
    end

    def <=>(other)
      other = Version.new(other)
      length = [parts.length, other.parts.length].max
      length.times do |i|
        a = parts[i]
        b = other.parts[i]

        return -1 if a.nil?
        return +1 if b.nil?
        return a.to_i <=> b.to_i if a != b
      end

      0
    end
  end

  module Generic
    include Helper

    attr_reader :log, :valkey

    alias r valkey

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

    def init(valkey)
      valkey.select 14
      valkey.flushdb
      valkey.select 15
      valkey.flushdb
      valkey
    rescue Valkey::CannotConnectError
      puts <<-MSG

        Cannot connect to Valkey.

        Make sure Valkey is running on localhost, port #{PORT}.
        This testing suite connects to the database 15.

        Try this once:

          $ make clean

        Then run the build again:

          $ make

      MSG
      exit 1
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
  end

  module Client
    include Generic

    private

    def _format_options(options)
      OPTIONS.merge(options)
    end

    def _new_client(options = {})
      Valkey.new(_format_options(options))
    end
  end
end
