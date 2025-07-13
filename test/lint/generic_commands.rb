# frozen_string_literal: true

module Lint
  module GenericCommands
    def test_copy
      target_version("6.2") do
        with_db(14) do
          r.flushdb

          r.set "foo", "s1"
          r.set "bar", "s2"

          assert r.copy("foo", "baz")
          assert_equal "s1", r.get("baz")

          assert !r.copy("foo", "bar")

          assert r.copy("foo", "bar", replace: true)
          assert_equal "s1", r.get("bar")
        end

        with_db(15) do
          r.set "foo", "s3"
          r.set "bar", "s4"
        end

        with_db(14) do
          assert r.copy("foo", "baz", db: 15)
          assert_equal "s1", r.get("foo")

          assert !r.copy("foo", "bar", db: 15)
          assert r.copy("foo", "bar", db: 15, replace: true)
        end

        with_db(15) do
          assert_equal "s1", r.get("baz")
          assert_equal "s1", r.get("bar")
        end
      end
    end
  end
end
