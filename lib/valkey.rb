# frozen_string_literal: true

require "ffi"
require "google/protobuf"

require "valkey/version"
require "valkey/request_type"
require "valkey/response_type"
require "valkey/protobuf/command_request_pb"
require "valkey/protobuf/connection_request_pb"
require "valkey/protobuf/response_pb"
require "valkey/bindings"
require "valkey/commands"
require "valkey/errors"

class Valkey
  include Commands

  def your_pubsub_callback(_client_ptr, kind, msg_ptr, msg_len, chan_ptr, chan_len, pat_ptr, pat_len)
    puts "PubSub received kind=#{kind}, message=#{msg_ptr.read_string(msg_len)}, channel=#{chan_ptr.read_string(chan_len)}, pattern=#{pat_ptr.read_string(pat_len)}"
  end

  def send_command(command_type, command_args = [])
    channel = 0
    route = "" # empty or some serialized route bytes

    arg_ptrs = FFI::MemoryPointer.new(:pointer, command_args.size)
    arg_lens = FFI::MemoryPointer.new(:ulong, command_args.size)
    buffers = []

    command_args.each_with_index do |arg, i|
      buf = FFI::MemoryPointer.from_string(arg)
      buffers << buf # prevent garbage collection
      arg_ptrs.put_pointer(i * FFI::Pointer.size, buf)
      arg_lens.put_ulong(i * 8, arg.bytesize)
    end

    route_buf = FFI::MemoryPointer.from_string(route)

    res = Bindings.command(
      @connection, # Assuming @connection is set after create
      channel,
      command_type,
      command_args.size,
      arg_ptrs,
      arg_lens,
      route_buf,
      route.bytesize
    )

    result = Bindings::CommandResult.new(res)[:response]

    # TODO: handle all types of responses
    case result[:response_type]
    when ResponseType::STRING
      result[:string_value].read_string(result[:string_value_len])
    when ResponseType::OK
      "OK"
    end
  end

  # TODO: use options
  def initialize(options = {})
    host = options[:host] || "127.0.0.1"
    port = options[:port] || 6379

    request = ConnectionRequest::ConnectionRequest.new(
      addresses: [ConnectionRequest::NodeAddress.new(host: host, port: port)]
    )

    client_type = Bindings::ClientType.new
    client_type[:tag] = 1 # AsyncClient

    request_str = ConnectionRequest::ConnectionRequest.encode(request)
    request_buf = FFI::MemoryPointer.new(:char, request_str.bytesize)
    request_buf.put_bytes(0, request_str)

    request_len = request_str.bytesize

    response_ptr = Bindings.create_client(
      request_buf,
      request_len,
      client_type,
      method(:your_pubsub_callback) # Pass the pubsub callback
    )

    res = Bindings::ConnectionResponse.new(response_ptr)

    @connection = res[:conn_ptr]
  end

  def close
    # TODO: handle closing the connection properly
  end

  alias disconnect! close
end
