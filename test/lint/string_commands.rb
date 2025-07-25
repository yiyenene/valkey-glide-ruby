# frozen_string_literal: true

module Lint
  module StringCommands
    def test_set_and_get
      r.set("foo", "s1")

      assert_equal "s1", r.get("foo")
    end

    def test_set_and_get_with_newline_characters
      r.set("foo", "1\n")

      assert_equal "1\n", r.get("foo")
    end

    def test_set_and_get_with_non_string_value
      value = %w[a b]

      r.set("foo", value)

      assert_equal value.to_s, r.get("foo")
    end

    def test_set_and_get_with_ascii_characters
      (0..255).each do |i|
        str = "#{i.chr}---#{i.chr}"
        r.set("foo", str)

        assert_equal str, r.get("foo")
      end
    end

    def test_set_with_ex
      r.set("foo", "bar", ex: 2)

      assert_in_range 0..2, r.ttl("foo")
    end

    def test_set_with_px
      r.set("foo", "bar", px: 2000)
      assert_in_range 0..2, r.ttl("foo")
    end

    def test_set_with_exat
      target_version "6.2" do
        r.set("foo", "bar", exat: Time.now.to_i + 2)
        assert_in_range 0..2, r.ttl("foo")
      end
    end

    def test_set_with_pxat
      target_version "6.2" do
        r.set("foo", "bar", pxat: (1000 * Time.now.to_i) + 2000)
        assert_in_range 0..2, r.ttl("foo")
      end
    end

    def test_set_with_nx
      r.set("foo", "qux", nx: true)
      assert !r.set("foo", "bar", nx: true)
      assert_equal "qux", r.get("foo")

      r.del("foo")
      assert r.set("foo", "bar", nx: true)
      assert_equal "bar", r.get("foo")
    end

    def test_set_with_xx
      r.set("foo", "qux")
      assert r.set("foo", "bar", xx: true)
      assert_equal "bar", r.get("foo")

      r.del("foo")
      assert !r.set("foo", "bar", xx: true)
    end

    def test_set_with_keepttl
      target_version "6.0.0" do
        r.set("foo", "qux", ex: 2)
        assert_in_range 0..2, r.ttl("foo")
        r.set("foo", "bar", keepttl: true)
        assert_in_range 0..2, r.ttl("foo")
      end
    end

    def test_set_with_get
      target_version "6.2" do
        r.set("foo", "qux")

        assert_equal "qux", r.set("foo", "bar", get: true)
        assert_equal "bar", r.get("foo")

        assert_nil r.set("baz", "bar", get: true)
        assert_equal "bar", r.get("baz")
      end
    end

    def test_setex
      skip "setex is deprecated in Redis 2.6.12"
      assert r.setex("foo", 1, "bar")
      assert_equal "bar", r.get("foo")
      assert [0, 1].include? r.ttl("foo")
    end

    def test_setex_with_non_string_value
      skip "setex is deprecated in Redis 2.6.12"
      value = %w[b a r]

      assert r.setex("foo", 1, value)
      assert_equal value.to_s, r.get("foo")
      assert [0, 1].include? r.ttl("foo")
    end

    def test_psetex
      skip "psetex is deprecated in Redis 2.6.12"
      assert r.psetex("foo", 1000, "bar")
      assert_equal "bar", r.get("foo")
      assert [0, 1].include? r.ttl("foo")
    end

    def test_psetex_with_non_string_value
      skip "psetex is deprecated in Redis 2.6.12"
      value = %w[b a r]

      assert r.psetex("foo", 1000, value)
      assert_equal value.to_s, r.get("foo")
      assert [0, 1].include? r.ttl("foo")
    end

    def test_getex
      target_version "6.2" do
        assert r.set("foo", "bar", ex: 1000)
        assert_equal "bar", r.getex("foo", persist: true)
        assert_equal(-1, r.ttl("foo"))
      end
    end

    def test_getdel
      target_version "6.2" do
        assert r.set("foo", "bar")
        assert_equal "bar", r.getdel("foo")
        assert_nil r.get("foo")
      end
    end

    def test_getset
      skip "getset is deprecated in Redis 6.2.0"
      r.set("foo", "bar")

      assert_equal "bar", r.getset("foo", "baz")
      assert_equal "baz", r.get("foo")
    end

    def test_getset_with_non_string_value
      skip "getset is deprecated in Redis 6.2.0"
      r.set("foo", "zap")

      value = %w[b a r]

      assert_equal "zap", r.getset("foo", value)
      assert_equal value.to_s, r.get("foo")
    end

    def test_setnx
      skip "setnx is deprecated in Redis 2.6.12"

      r.set("foo", "qux")
      assert !r.setnx("foo", "bar")
      assert_equal "qux", r.get("foo")

      r.del("foo")
      assert r.setnx("foo", "bar")
      assert_equal "bar", r.get("foo")
    end

    def test_setnx_with_non_string_value
      skip "setnx is deprecated in Redis 2.6.12"

      value = %w[b a r]

      r.set("foo", "qux")
      assert !r.setnx("foo", value)
      assert_equal "qux", r.get("foo")

      r.del("foo")
      assert r.setnx("foo", value)
      assert_equal value.to_s, r.get("foo")
    end

    def test_incr
      assert_equal 1, r.incr("foo")
      assert_equal 2, r.incr("foo")
      assert_equal 3, r.incr("foo")
    end

    def test_incrby
      assert_equal 1, r.incrby("foo", 1)
      assert_equal 3, r.incrby("foo", 2)
      assert_equal 6, r.incrby("foo", 3)
    end

    def test_incrbyfloat
      assert_equal 1.23, r.incrbyfloat("foo", 1.23)
      assert_equal 2, r.incrbyfloat("foo", 0.77)
      assert_equal 1.9, r.incrbyfloat("foo", -0.1)
    end

    def test_decr
      r.set("foo", 3)

      assert_equal 2, r.decr("foo")
      assert_equal 1, r.decr("foo")
      assert_equal 0, r.decr("foo")
    end

    def test_decrby
      r.set("foo", 6)

      assert_equal 3, r.decrby("foo", 3)
      assert_equal 1, r.decrby("foo", 2)
      assert_equal 0, r.decrby("foo", 1)
    end

    def test_append
      r.set "foo", "s"
      r.append "foo", "1"

      assert_equal "s1", r.get("foo")
    end

    def test_getrange
      r.set("foo", "abcde")

      assert_equal "bcd", r.getrange("foo", 1, 3)
      assert_equal "abcde", r.getrange("foo", 0, -1)
    end

    def test_setrange
      r.set("foo", "abcde")

      r.setrange("foo", 1, "bar")

      assert_equal "abare", r.get("foo")
    end

    def test_setrange_with_non_string_value
      r.set("foo", "abcde")

      value = %w[b a r]

      r.setrange("foo", 2, value)

      assert_equal "ab#{value}", r.get("foo")
    end

    def test_strlen
      r.set "foo", "lorem"

      assert_equal 5, r.strlen("foo")
    end

    def test_mget
      r.set('{1}foo', 's1')
      r.set('{1}bar', 's2')

      assert_equal %w[s1 s2],         r.mget('{1}foo', '{1}bar')
      assert_equal ['s1', 's2', nil], r.mget('{1}foo', '{1}bar', '{1}baz')
      assert_equal ['s1', 's2', nil], r.mget(['{1}foo', '{1}bar', '{1}baz'])
    end

    def test_mget_mapped
      r.set('{1}foo', 's1')
      r.set('{1}bar', 's2')

      response = r.mapped_mget('{1}foo', '{1}bar')

      assert_equal 's1', response['{1}foo']
      assert_equal 's2', response['{1}bar']

      response = r.mapped_mget('{1}foo', '{1}bar', '{1}baz')

      assert_equal 's1', response['{1}foo']
      assert_equal 's2', response['{1}bar']
      assert_nil response['{1}baz']
    end

    def test_mapped_mget_in_a_pipeline_returns_hash
      r.set('{1}foo', 's1')
      r.set('{1}bar', 's2')

      result = r.pipelined do |pipeline|
        pipeline.mapped_mget('{1}foo', '{1}bar')
      end

      assert_equal({ '{1}foo' => 's1', '{1}bar' => 's2' }, result[0])
    end

    def test_mset
      r.mset('{1}foo', 's1', '{1}bar', 's2')

      assert_equal 's1', r.get('{1}foo')
      assert_equal 's2', r.get('{1}bar')
    end

    def test_mset_mapped
      r.mapped_mset('{1}foo' => 's1', '{1}bar' => 's2')

      assert_equal 's1', r.get('{1}foo')
      assert_equal 's2', r.get('{1}bar')
    end

    def test_msetnx
      r.set('{1}foo', 's1')
      assert_equal false, r.msetnx('{1}foo', 's2', '{1}bar', 's3')
      assert_equal 's1', r.get('{1}foo')
      assert_nil r.get('{1}bar')

      r.del('{1}foo')
      assert_equal true, r.msetnx('{1}foo', 's2', '{1}bar', 's3')
      assert_equal 's2', r.get('{1}foo')
      assert_equal 's3', r.get('{1}bar')
    end

    def test_msetnx_mapped
      r.set('{1}foo', 's1')
      assert_equal false, r.mapped_msetnx('{1}foo' => 's2', '{1}bar' => 's3')
      assert_equal 's1', r.get('{1}foo')
      assert_nil r.get('{1}bar')

      r.del('{1}foo')
      assert_equal true, r.mapped_msetnx('{1}foo' => 's2', '{1}bar' => 's3')
      assert_equal 's2', r.get('{1}foo')
      assert_equal 's3', r.get('{1}bar')
    end

    def test_lcs
      target_version "7.0" do
        r.mset('key1', 'ohmytext', 'key2', 'mynewtext')
        assert_equal "mytext", r.lcs('key1', 'key2')

        assert_equal ["matches", [
          [
            [4, 7],
            [5, 8]
          ],
          [
            [2, 3],
            [0, 1]
          ]
        ], "len", 6], r.lcs('key1', 'key2', idx: true)

        assert_equal ["matches", [
          [
            [4, 7],
            [5, 8]
          ]
        ], "len", 6], r.lcs('key1', 'key2', idx: true, min_match_len: 4)
      end

      assert_equal ["matches", [
        [
          [4, 7],
          [5, 8],
          4
        ]
      ], "len", 6], r.lcs('key1', 'key2', idx: true, min_match_len: 4, with_match_len: true)
    end
  end
end
