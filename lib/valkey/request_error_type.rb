# frozen_string_literal: true

class Valkey
  module RequestErrorType
    UNSPECIFIED = 0
    EXECABORT = 1
    TIMEOUT = 2
    DISCONNECT = 3
  end
end
