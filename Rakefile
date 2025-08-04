# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'

namespace :test do
  groups = %i[valkey cluster]
  groups.each do |group|
    Rake::TestTask.new(group) do |t|
      t.libs << "test"
      t.libs << "lib"
      t.test_files = FileList["test/#{group}/**/*_test.rb"]
      t.options = '-v' if ENV['CI'] || ENV['VERBOSE']
    end
  end

  lost_tests = Dir["test/**/*_test.rb"] - groups.map { |g| Dir["test/#{g}/**/*_test.rb"] }.flatten
  abort "The following test files are in no group:\n#{lost_tests.join("\n")}" unless lost_tests.empty?
end

task test: ["test:valkey"]

task default: :test
