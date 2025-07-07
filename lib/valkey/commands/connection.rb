# frozen_string_literal: true

class Valkey
  module Commands
    # This module contains commands related to connection management.
    module Connection
      # Authenticate to the server.
      #
      # @param [Array<String>] args includes both username and password
      #   or only password
      # @return [String] `OK`
      # @see https://redis.io/commands/auth AUTH command
      def auth(*args)
        # TODO:
        # send_command([:auth, *args])
      end

      # Ping the server.
      #
      # @param [optional, String] message
      # @return [String] `PONG`
      def ping(message = nil)
        # TODO:
        # send_command([:ping, message].compact)
      end

      # Echo the given string.
      #
      # @param [String] value
      # @return [String]
      def echo(value)
        # TODO:
        # send_command([:echo, value])
      end

      # Change the selected database for the current connection.
      #
      # @param [Integer] db zero-based index of the DB to use (0 to 15)
      # @return [String] `OK`
      def select(db)
        # TODO:
        # send_command(RequestType::SELECT, [db.to_s])
      end

      # Close the connection.
      #
      # @return [String] `OK`
      def quit
        # TODO:
        # synchronize do |client|
        #   client.call_v([:quit])
        # rescue ConnectionError
        # ensure
        #   client.close
        # end
      end
    end
  end
end
