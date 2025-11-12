# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "valkey"

require "minitest/autorun"
require 'minitest/reporters'

require_relative 'support/helper/generic'
require_relative 'support/helper/version'
require_relative 'support/helper/client'
require_relative 'support/helper/cluster'

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

$VERBOSE = true

HOST        = ENV.fetch('VALKEY_HOST', "127.0.0.1")
PORT        = 6379
DB          = 15
TIMEOUT = Float(ENV["TIMEOUT"] || 5.0) # Increased from 3.0 to 5.0 for CI stability
LOW_TIMEOUT = Float(ENV["LOW_TIMEOUT"] || 0.01) # for blocking-command tests

# Cluster nodes: use CLUSTER_HOST if set (for Docker), otherwise use HOST
CLUSTER_HOST = ENV.fetch('CLUSTER_HOST', HOST)
CLUSTER_NODES =
  if CLUSTER_HOST == HOST
    # CI or local (host-based): connect to 127.0.0.1:7000-7005
    6.times.map { |i| { host: HOST, port: 7000 + i } }
  else
    # Docker environment: connect to valkey-cluster-1:7000, etc.
    6.times.map { |i| { host: "#{CLUSTER_HOST}-#{i + 1}", port: 7000 + i } }
  end

Dir[File.expand_path("lint/**/*.rb", __dir__)].sort.each do |f|
  require f
end
