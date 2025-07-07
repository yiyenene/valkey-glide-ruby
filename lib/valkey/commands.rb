# frozen_string_literal: true

require "valkey/commands/strings"
require "valkey/commands/connection"
require "valkey/commands/server"

class Valkey
  module Commands
    include Strings
    include Connection
    include Server
  end
end
