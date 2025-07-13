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

    def test_del
      r.set "foo", "s1"
      r.set "bar", "s2"
      r.set "baz", "s3"

      assert_equal %w[bar baz foo], all_keys

      assert_equal 0, r.del("")

      assert_equal 1, r.del("foo")

      assert_equal %w[bar baz], all_keys

      assert_equal 2, r.del("bar", "baz")

      assert_equal [], all_keys
    end

    def test_del_with_array_argument
      r.set "foo", "s1"
      r.set "bar", "s2"
      r.set "baz", "s3"

      assert_equal %w[bar baz foo], all_keys

      assert_equal 0, r.del([])

      assert_equal 1, r.del(["foo"])

      assert_equal %w[bar baz], all_keys

      assert_equal 2, r.del(%w[bar baz])

      assert_equal [], all_keys
    end

    def test_dump_and_restore
      r.set("foo", "a")
      v = r.dump("foo")
      r.del("foo")

      assert r.restore("foo", 1000, v)
      assert_equal "a", r.get("foo")
      assert [0, 1].include? r.ttl("foo")

      r.rpush("bar", %w[b c d])
      w = r.dump("bar")
      r.del("bar")

      assert r.restore("bar", 1000, w)
      assert_equal %w[b c d], r.lrange("bar", 0, -1)
      assert [0, 1].include? r.ttl("bar")

      r.set("bar", "somethingelse")
      assert_raises(Valkey::CommandError) { r.restore("bar", 1000, w) } # ensure by default replace is false
      assert_raises(Valkey::CommandError) { r.restore("bar", 1000, w, replace: false) }
      assert_equal "somethingelse", r.get("bar")
      assert r.restore("bar", 1000, w, replace: true)
      assert_equal %w[b c d], r.lrange("bar", 0, -1)
      assert [0, 1].include? r.ttl("bar")
    end

    def test_exists
      assert_equal 0, r.exists("foo")

      r.set("foo", "s1")

      assert_equal 1, r.exists("foo")
      assert_equal 1, r.exists(["foo"])
    end

    def test_variadic_exists
      assert_equal 0, r.exists("{1}foo", "{1}bar")

      r.set("{1}foo", "s1")

      assert_equal 1, r.exists("{1}foo", "{1}bar")

      r.set("{1}bar", "s2")

      assert_equal 2, r.exists("{1}foo", "{1}bar")
      assert_equal 2, r.exists(["{1}foo", "{1}bar"])
    end

    def test_exists?
      assert_equal false, r.exists?("{1}foo", "{1}bar")

      r.set("{1}foo", "s1")

      assert_equal true, r.exists?("{1}foo")
      assert_equal true, r.exists?(["{1}foo"])

      r.set("{1}bar", "s1")

      assert_equal true, r.exists?("{1}foo", "{1}bar")
      assert_equal true, r.exists?(["{1}foo", "{1}bar"])
    end

    def test_expire
      r.set("foo", "s1")
      assert r.expire("foo", 2)
      assert_in_range 0..2, r.ttl("foo")

      target_version "7.0.0" do
        r.set("bar", "s2")
        refute r.expire("bar", 5, xx: true)
        assert r.expire("bar", 5, nx: true)
        refute r.expire("bar", 5, nx: true)
        assert r.expire("bar", 5, xx: true)

        r.expire("bar", 10)
        refute r.expire("bar", 15, lt: true)
        refute r.expire("bar", 5, gt: true)
        assert r.expire("bar", 15, gt: true)
        assert r.expire("bar", 5, lt: true)
      end
    end

    def test_expireat
      r.set("foo", "s1")
      assert r.expireat("foo", (Time.now + 2).to_i)
      assert_in_range 0..2, r.ttl("foo")
    end

    def test_expireat_keywords
      target_version "7.0.0" do
        r.set("bar", "s2")
        refute r.expireat("bar", (Time.now + 5).to_i, xx: true)
        assert r.expireat("bar", (Time.now + 5).to_i, nx: true)
        refute r.expireat("bar", (Time.now + 5).to_i, nx: true)
        assert r.expireat("bar", (Time.now + 5).to_i, xx: true)

        r.expireat("bar", (Time.now + 10).to_i)
        refute r.expireat("bar", (Time.now + 15).to_i, lt: true)
        refute r.expireat("bar", (Time.now + 5).to_i, gt: true)
        assert r.expireat("bar", (Time.now + 15).to_i, gt: true)
        assert r.expireat("bar", (Time.now + 5).to_i, lt: true)
      end
    end
  end
end
