# frozen_string_literal: true

require "ffi"
require "google/protobuf"

require "valkey/version"
require "valkey/request_type"
require "valkey/response_type"
require "valkey/request_error_type"
require "valkey/protobuf/command_request_pb"
require "valkey/protobuf/connection_request_pb"
require "valkey/protobuf/response_pb"
require "valkey/bindings"
require "valkey/utils"
require "valkey/commands"
require "valkey/errors"
require "valkey/pubsub_callback"
require "valkey/pipeline"

class Valkey
  include Utils
  include Commands
  include PubSubCallback

  def pipelined(exception: true)
    pipeline = Pipeline.new

    yield pipeline

    return if pipeline.commands.empty?

    send_batch_commands(pipeline.commands, exception: exception)
  end

  def send_batch_commands(commands, exception: true)
    cmds = []
    blocks = []

    commands.each do |command_type, command_args, block|
      arg_ptrs, arg_lens = build_command_args(command_args)

      cmd = Bindings::CmdInfo.new
      cmd[:request_type] = command_type
      cmd[:args] = arg_ptrs
      cmd[:arg_count] = command_args.size
      cmd[:args_len] = arg_lens

      cmds << cmd
      blocks << block
    end

    batch_info = Bindings::BatchInfo.new
    batch_info[:cmd_count] = cmds.size
    batch_info[:cmds] = FFI::MemoryPointer.new(Bindings::CmdInfo, cmds.size)

    cmds.each_with_index do |cmd, i|
      batch_info[:cmds].put_pointer(i * Bindings::CmdInfo.size, cmd.to_ptr)
    end

    batch_options = Bindings::BatchOptionsInfo.new
    batch_options[:retry_server_error] = true
    batch_options[:retry_connection_error] = true
    batch_options[:has_timeout] = false
    batch_options[:timeout] = 0 # No timeout

    res = Bindings.batch(
      @connection, # Assuming @connection is set after create
      0,
      batch_info,
      exception,
      batch_options,
      0
    )

    results = convert_response(res)

    blocks.each_with_index do |block, i|
      results[i] = block.call(results[i]) if block
    end

    results
  end

  def build_command_args(command_args)
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

    [arg_ptrs, arg_lens]
  end

  def convert_response(res, &block)
    result = Bindings::CommandResult.new(res)

    if result[:response].null?
      error = result[:command_error]

      case error[:command_error_type]
      when RequestErrorType::EXECABORT, RequestErrorType::UNSPECIFIED
        raise CommandError, error[:command_error_message]
      when RequestErrorType::TIMEOUT
        raise TimeoutError, error[:command_error_message]
      when RequestErrorType::DISCONNECT
        raise ConnectionError, error[:command_error_message]
      else
        raise "Unknown error type: #{error[:command_error_type]}"
      end
    end

    result = result[:response]

    response = recursive_convert_response(result)

    if block_given?
      block.call(response)
    else
      response
    end
  end

  def recursive_convert_response(result)
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
        recursive_convert_response(item)
      end
    when ResponseType::MAP
      return nil if result[:array_value].null?

      ptr = result[:array_value]
      count = result[:array_value_len].to_i
      mapped_arr = 
        Array.new(count) do |i|
          item = Bindings::CommandResponse.new(ptr + i * Bindings::CommandResponse.size)

          map_key = recursive_convert_response(Bindings::CommandResponse.new(item[:map_key]))
          map_value = recursive_convert_response(Bindings::CommandResponse.new(item[:map_value]))

          map_value = map_value.flatten(1) if detect_array_of_pairs(map_value)
          
          [map_key, map_value]
        end
      
      if count > 0 && mapped_arr[0][1].is_a?(Array)
        mapped_arr
      else
        mapped_arr.flatten(1)
      end
    when ResponseType::SETS
      ptr = result[:sets_value]
      count = result[:sets_value_len].to_i

      Array.new(count) do |i|
        item = Bindings::CommandResponse.new(ptr + i * Bindings::CommandResponse.size)
        recursive_convert_response(item)
      end
    when ResponseType::NULL
      nil
    when ResponseType::OK
      "OK"
    else
      raise "Unsupported response type: #{result[:response_type]}"
    end
  end

  def detect_array_of_pairs(object)
    # Believe that Glide won't return mixed array of pairs and non-pairs
    object.is_a?(Array) && object[0].is_a?(Array) && object[0].size == 2
  end

  def send_command(command_type, command_args = [], &block)        # Validate connection
    if @connection.nil?
      raise "Connection is nil"
    elsif @connection.null?
      raise "Connection pointer is null"
    elsif @connection.address.zero?
      raise "Connection address is 0"
    end

    channel = 0
    route = ""

    route_buf = FFI::MemoryPointer.from_string(route)

    # Handle empty command_args case
    if command_args.empty?
      arg_ptrs = FFI::MemoryPointer.new(:pointer, 1)
      arg_lens = FFI::MemoryPointer.new(:ulong, 1)
      arg_ptrs.put_pointer(0, FFI::MemoryPointer.new(1))
      arg_lens.put_ulong(0, 0)
    else
      arg_ptrs, arg_lens = build_command_args(command_args)
    end

    res = Bindings.command(
      @connection,
      channel,
      command_type,
      command_args.size,
      arg_ptrs,
      arg_lens,
      route_buf,
      route.bytesize,
      0
    )

    convert_response(res, &block)
  end

  def initialize(options = {})
    host = options[:host] || "127.0.0.1"
    port = options[:port] || 6379

    nodes = options[:nodes] || [{ host: host, port: port }]

    cluster_mode_enabled = options[:cluster_mode] || false

    request = ConnectionRequest::ConnectionRequest.new(
      cluster_mode_enabled: cluster_mode_enabled,
      request_timeout: options[:timeout] || 3.0,
      addresses: nodes.map { |node| ConnectionRequest::NodeAddress.new(host: node[:host], port: node[:port]) }
    )

    client_type = Bindings::ClientType.new
    client_type[:tag] = 1 # SyncClient

    request_str = ConnectionRequest::ConnectionRequest.encode(request)
    request_buf = FFI::MemoryPointer.new(:char, request_str.bytesize)
    request_buf.put_bytes(0, request_str)

    request_len = request_str.bytesize

    response_ptr = Bindings.create_client(
      request_buf,
      request_len,
      client_type,
      method(:pubsub_callback)
    )

    res = Bindings::ConnectionResponse.new(response_ptr)

    # Check if connection was successful
    if res[:conn_ptr].null?
      error_message = res[:connection_error_message]
      raise CannotConnectError, "Failed to connect to cluster: #{error_message}"
    end

    @connection = res[:conn_ptr]
  end

  def close
    return if @connection.nil? || @connection.null?

    Bindings.close_client(@connection)
    @connection = nil
  end

  alias disconnect! close
end
