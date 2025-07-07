# frozen_string_literal: true

require "test_helper"

class TestCommandsOnStrings < Minitest::Test
  include Helper::Client
  include Lint::Strings
end
