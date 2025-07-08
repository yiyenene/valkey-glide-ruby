# frozen_string_literal: true

require "valkey/commands/strings"
require "valkey/commands/connection"
require "valkey/commands/server"
require "valkey/commands/keys"
require "valkey/commands/bitmaps"


class Valkey
  module Commands
    include Strings
    include Connection
    include Server
    include Keys
    include Bitmaps

    # # Commands returning 1 for true and 0 for false may be executed in a pipeline
    # # where the method call will return nil. Propagate the nil instead of falsely
    # # returning false.
    # Boolify = lambda { |value|
    #   value != 0 unless value.nil?
    # }
    #
    # BoolifySet = lambda { |value|
    #   case value
    #   when "OK"
    #     true
    #   when nil
    #     false
    #   else
    #     value
    #   end
    # }
    HashifyInfo = lambda { |reply|
      lines = reply.split("\r\n").grep_v(/^(#|$)/)
      lines.map! { |line| line.split(':', 2) }
      lines.compact!
      lines.to_h
    }
  end
end
