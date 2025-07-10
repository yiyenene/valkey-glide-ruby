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
    puts "PubSub received kind=#{kind}, message=#{msg_ptr.read_string(msg_len)}"\
          ", channel=#{chan_ptr.read_string(chan_len)}, pattern=#{pat_ptr.read_string(pat_len)}"
  end

  def send_command(command_type, command_args = [], &block)
    channel = 0
    route = "" # empty or some serialized route bytes

    arg_ptrs = FFI::MemoryPointer.new(:pointer, command_args.size)
    arg_lens = FFI::MemoryPointer.new(:ulong, command_args.size)
    buffers = []

    command_args.each_with_index do |arg, i|
      arg = arg.to_s # Ensure we convert to string

      buf = FFI::MemoryPointer.from_string(arg.to_s)
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

    convert_response = lambda { |result|
      # TODO: handle all types of responses
      case result[:response_type]
      when ResponseType::STRING
        result[:string_value].read_string(result[:string_value_len])
      when ResponseType::INT
        result[:int_value]
      when ResponseType::FLOAT
        result[:float_value]
      when ResponseType::BOOL
        result[:bool_value]
      when ResponseType::ARRAY
        ptr = result[:array_value]
        count = result[:array_value_len].to_i

        Array.new(count) do |i|
          item = Bindings::CommandResponse.new(ptr + i * Bindings::CommandResponse.size)
          convert_response.call(item)
        end
      when ResponseType::NULL
        nil
      when ResponseType::OK
        "OK"
      else
        raise "Unsupported response type: #{result[:response_type]}"
      end
    }

    response = convert_response.call(result)

    if block_given?
      block.call(response)
    else
      response
    end
  end

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
    Bindings.close_client(@connection)
  end

  alias disconnect! close
end
