# frozen_string_literal: true

module Lint
  module StreamCommands
    ENTRY_ID_FORMAT = /\d+-\d+/.freeze

    def test_xinfo_with_stream_subcommand
      r.xadd('s1', { f: 'v1' })
      r.xadd('s1', { f: 'v2' })
      r.xadd('s1', { f: 'v3' })
      r.xadd('s1', { f: 'v4' })
      r.xgroup(:create, 's1', 'g1', '$')

      actual = r.xinfo(:stream, 's1')

      assert_match ENTRY_ID_FORMAT, actual['last-generated-id']
      assert_equal 4, actual['length']
      assert_equal 1, actual['groups']
      assert_equal true, actual.key?('radix-tree-keys')
      assert_equal true, actual.key?('radix-tree-nodes')
      assert_kind_of Array, actual['first-entry']
      assert_kind_of Array, actual['last-entry']
    end

    def test_xinfo_with_groups_subcommand
      r.xadd('s1', { f: 'v' })
      r.xgroup(:create, 's1', 'g1', '$')

      actual = r.xinfo(:groups, 's1').first

      assert_equal 0, actual['consumers']
      assert_equal 0, actual['pending']
      assert_equal 'g1', actual['name']
      assert_match ENTRY_ID_FORMAT, actual['last-delivered-id']
    end

    def test_xinfo_with_consumers_subcommand
      r.xadd('s1', { f: 'v' })
      r.xgroup(:create, 's1', 'g1', '$')
      assert_equal [], r.xinfo(:consumers, 's1', 'g1')
    end

    def test_xinfo_with_invalid_arguments
      assert_raises(Valkey::CommandError) { r.xinfo('', '', '') }
      assert_raises(Valkey::CommandError) { r.xinfo(nil, nil, nil) }
      assert_raises(Valkey::CommandError) { r.xinfo(:stream, nil) }
      assert_raises(Valkey::CommandError) { r.xinfo(:groups, nil) }
      assert_raises(Valkey::CommandError) { r.xinfo(:consumers, nil) }
      assert_raises(Valkey::CommandError) { r.xinfo(:consumers, 's1', nil) }
    end

    def test_xadd_with_entry_as_splatted_params
      assert_match ENTRY_ID_FORMAT, r.xadd('s1', { f1: 'v1', f2: 'v2' })
    end

    def test_xadd_with_entry_as_a_hash_literal
      entry = { f1: 'v1', f2: 'v2' }
      assert_match ENTRY_ID_FORMAT, r.xadd('s1', entry)
    end

    def test_xadd_with_entry_id_option
      entry_id = "#{Time.now.strftime('%s%L')}-14"
      assert_equal entry_id, r.xadd('s1', { f1: 'v1', f2: 'v2' }, id: entry_id)
    end

    def test_xadd_with_invalid_entry_id_option
      entry_id = 'invalid-format-entry-id'
      assert_raises(Valkey::CommandError, 'ERR Invalid stream ID specified as stream command argument') do
        r.xadd('s1', { f1: 'v1', f2: 'v2' }, id: entry_id)
      end
    end

    def test_xadd_with_old_entry_id_option
      r.xadd('s1', { f1: 'v1', f2: 'v2' }, id: '0-1')
      err_msg = 'ERR The ID specified in XADD is equal or smaller than the target stream top item'
      assert_raises(Valkey::CommandError, err_msg) do
        r.xadd('s1', { f1: 'v1', f2: 'v2' }, id: '0-0')
      end
    end

    def test_xadd_with_maxlen_and_approximate_option
      actual = r.xadd('s1', { f1: 'v1', f2: 'v2' }, maxlen: 2, approximate: true)
      assert_match ENTRY_ID_FORMAT, actual
    end

    def test_xadd_with_minid_and_approximate_option
      actual = r.xadd('s1', { f1: 'v1', f2: 'v2' }, minid: '0-1', approximate: true)
      assert_match ENTRY_ID_FORMAT, actual
    end

    def test_xadd_with_both_maxlen_and_minid
      assert_raises(ArgumentError) { r.xadd('s1', { f1: 'v1', f2: 'v2' }, maxlen: 2, minid: '0-1', approximate: true) }
    end

    def test_xadd_with_nomkstream_option
      actual = r.xadd('s1', { f1: 'v1', f2: 'v2' }, nomkstream: true)
      assert_nil actual

      actual = r.xadd('s1', { f1: 'v1', f2: 'v2' }, nomkstream: false)
      assert_match ENTRY_ID_FORMAT, actual
    end

    def test_xadd_with_invalid_arguments
      assert_raises(Valkey::CommandError) { r.xadd(nil, {}) }
      assert_raises(Valkey::CommandError) { r.xadd('', {}) }
      assert_raises(Valkey::CommandError) { r.xadd('s1', {}) }
    end

    def test_xtrim
      r.xadd('s1', { f: 'v1' })
      r.xadd('s1', { f: 'v2' })
      r.xadd('s1', { f: 'v3' })
      r.xadd('s1', { f: 'v4' })
      assert_equal 2, r.xtrim('s1', 2)
    end

    def test_xtrim_with_approximate_option
      r.xadd('s1', { f: 'v1' })
      r.xadd('s1', { f: 'v2' })
      r.xadd('s1', { f: 'v3' })
      r.xadd('s1', { f: 'v4' })
      assert_equal 0, r.xtrim('s1', 2, approximate: true)
    end

    def test_xtrim_with_limit_option
      begin
        original = r.config(:get, 'stream-node-max-entries')['stream-node-max-entries']
        r.config(:set, 'stream-node-max-entries', 1)

        r.xadd('s1', { f: 'v1' })
        r.xadd('s1', { f: 'v2' })
        r.xadd('s1', { f: 'v3' })
        r.xadd('s1', { f: 'v4' })

        assert_equal 1, r.xtrim('s1', 0, approximate: true, limit: 1)
        error = assert_raises(Valkey::CommandError) { r.xtrim('s1', 0, limit: 1) }
        assert_includes error.message, "syntax error, LIMIT cannot be used without the special ~ option"
      ensure
        r.config(:set, 'stream-node-max-entries', original)
      end
    end

    def test_xtrim_with_maxlen_strategy
      r.xadd('s1', { f: 'v1' }, id: '0-1')
      r.xadd('s1', { f: 'v1' }, id: '0-2')
      r.xadd('s1', { f: 'v1' }, id: '1-0')
      r.xadd('s1', { f: 'v1' }, id: '1-1')
      assert_equal(2, r.xtrim('s1', 2, strategy: 'MAXLEN'))
    end

    def test_xtrim_with_minid_strategy
      r.xadd('s1', { f: 'v1' }, id: '0-1')
      r.xadd('s1', { f: 'v1' }, id: '0-2')
      r.xadd('s1', { f: 'v1' }, id: '1-0')
      r.xadd('s1', { f: 'v1' }, id: '1-1')
      assert_equal(2, r.xtrim('s1', '1-0', strategy: 'MINID'))
    end

    def test_xtrim_with_approximate_minid_strategy
      r.xadd('s1', { f: 'v1' }, id: '0-1')
      r.xadd('s1', { f: 'v1' }, id: '0-2')
      r.xadd('s1', { f: 'v1' }, id: '1-0')
      r.xadd('s1', { f: 'v1' }, id: '1-1')
      assert_equal(0, r.xtrim('s1', '1-0', strategy: 'MINID', approximate: true))
    end

    def test_xtrim_with_invalid_strategy
      r.xadd('s1', { f: 'v1' })
      error = assert_raises(Valkey::CommandError) { r.xtrim('s1', '1-0', strategy: '') }
      assert_includes error.message, "syntax error"
    end

    def test_xtrim_with_not_existed_stream
      assert_equal 0, r.xtrim('not-existed-stream', 2)
    end

    def test_xtrim_with_invalid_arguments
      assert_raises(Valkey::CommandError) { r.xtrim('', '') }
      assert_equal 0, r.xtrim('s1', 0)
      assert_raises(Valkey::CommandError) { r.xtrim('s1', -1, approximate: true) }
    end

    def test_xdel_with_splatted_entry_ids
      r.xadd('s1', { f: '1' }, id: '0-1')
      r.xadd('s1', { f: '2' }, id: '0-2')
      assert_equal 2, r.xdel('s1', '0-1', '0-2', '0-3')
    end

    def test_xdel_with_arrayed_entry_ids
      r.xadd('s1', { f: '1' }, id: '0-1')
      assert_equal 1, r.xdel('s1', ['0-1', '0-2'])
    end

    def test_xdel_with_invalid_entry_ids
      assert_equal 0, r.xdel('s1', 'invalid_format')
    end

    def test_xdel_with_invalid_arguments
      assert_raises(TypeError) { r.xdel(nil, nil) }
      assert_raises(TypeError) { r.xdel(nil, [nil]) }
      assert_equal 0, r.xdel('', '')
      assert_equal 0, r.xdel('', [''])
      assert_raises(Valkey::CommandError) { r.xdel('s1', []) }
    end

    def test_xrange
      r.xadd('s1', { f: 'v1' }, id: '0-1')
      r.xadd('s1', { f: 'v2' }, id: '0-2')
      r.xadd('s1', { f: 'v3' }, id: '0-3')

      actual = r.xrange('s1')

      assert_equal(%w(v1 v2 v3), actual.map { |i| i.last['f'] })
    end

    def test_xrange_with_start_option
      r.xadd('s1', { f: 'v' }, id: '0-1')
      r.xadd('s1', { f: 'v' }, id: '0-2')
      r.xadd('s1', { f: 'v' }, id: '0-3')

      actual = r.xrange('s1', '0-2')

      assert_equal %w(0-2 0-3), actual.map(&:first)
    end

    def test_xrange_with_end_option
      r.xadd('s1', { f: 'v' }, id: '0-1')
      r.xadd('s1', { f: 'v' }, id: '0-2')
      r.xadd('s1', { f: 'v' }, id: '0-3')

      actual = r.xrange('s1', '-', '0-2')
      assert_equal %w(0-1 0-2), actual.map(&:first)
    end

    def test_xrange_with_start_and_end_options
      r.xadd('s1', { f: 'v' }, id: '0-1')
      r.xadd('s1', { f: 'v' }, id: '0-2')
      r.xadd('s1', { f: 'v' }, id: '0-3')

      actual = r.xrange('s1', '0-2', '0-2')

      assert_equal %w(0-2), actual.map(&:first)
    end

    def test_xrange_with_incomplete_entry_id_options
      r.xadd('s1', { f: 'v' }, id: '0-1')
      r.xadd('s1', { f: 'v' }, id: '1-1')
      r.xadd('s1', { f: 'v' }, id: '2-1')

      actual = r.xrange('s1', '0', '1')

      assert_equal 2, actual.size
      assert_equal %w(0-1 1-1), actual.map(&:first)
    end

    def test_xrange_with_count_option
      r.xadd('s1', { f: 'v' }, id: '0-1')
      r.xadd('s1', { f: 'v' }, id: '0-2')
      r.xadd('s1', { f: 'v' }, id: '0-3')

      actual = r.xrange('s1', count: 2)

      assert_equal %w(0-1 0-2), actual.map(&:first)
    end

    def test_xrange_with_not_existed_stream_key
      assert_equal([], r.xrange('not-existed'))
    end

    def test_xrange_with_invalid_entry_id_options
      assert_raises(Valkey::CommandError) { r.xrange('s1', 'invalid', 'invalid') }
    end

    def test_xrange_with_invalid_arguments
      assert_raises(TypeError) { r.xrange(nil) }
      assert_equal([], r.xrange(''))
    end

    def test_xrevrange
      r.xadd('s1', { f: 'v1' }, id: '0-1')
      r.xadd('s1', { f: 'v2' }, id: '0-2')
      r.xadd('s1', { f: 'v3' }, id: '0-3')

      actual = r.xrevrange('s1')

      assert_equal %w(0-3 0-2 0-1), actual.map(&:first)
      assert_equal(%w(v3 v2 v1), actual.map { |i| i.last['f'] })
    end

    def test_xrevrange_with_start_option
      r.xadd('s1', { f: 'v' }, id: '0-1')
      r.xadd('s1', { f: 'v' }, id: '0-2')
      r.xadd('s1', { f: 'v' }, id: '0-3')

      actual = r.xrevrange('s1', '+', '0-2')

      assert_equal %w(0-3 0-2), actual.map(&:first)
    end

    def test_xrevrange_with_end_option
      r.xadd('s1', { f: 'v' }, id: '0-1')
      r.xadd('s1', { f: 'v' }, id: '0-2')
      r.xadd('s1', { f: 'v' }, id: '0-3')

      actual = r.xrevrange('s1', '0-2')

      assert_equal %w(0-2 0-1), actual.map(&:first)
    end

    def test_xrevrange_with_start_and_end_options
      r.xadd('s1', { f: 'v' }, id: '0-1')
      r.xadd('s1', { f: 'v' }, id: '0-2')
      r.xadd('s1', { f: 'v' }, id: '0-3')

      actual = r.xrevrange('s1', '0-2', '0-2')

      assert_equal %w(0-2), actual.map(&:first)
    end

    def test_xrevrange_with_incomplete_entry_id_options
      r.xadd('s1', { f: 'v' }, id: '0-1')
      r.xadd('s1', { f: 'v' }, id: '1-1')
      r.xadd('s1', { f: 'v' }, id: '2-1')

      actual = r.xrevrange('s1', '1', '0')

      assert_equal 2, actual.size
      assert_equal '1-1', actual.first.first
    end

    def test_xrevrange_with_count_option
      r.xadd('s1', { f: 'v' }, id: '0-1')
      r.xadd('s1', { f: 'v' }, id: '0-2')
      r.xadd('s1', { f: 'v' }, id: '0-3')

      actual = r.xrevrange('s1', count: 2)

      assert_equal 2, actual.size
      assert_equal '0-3', actual.first.first
    end

    def test_xrevrange_with_not_existed_stream_key
      assert_equal([], r.xrevrange('not-existed'))
    end

    def test_xrevrange_with_invalid_entry_id_options
      assert_raises(Valkey::CommandError) { r.xrevrange('s1', 'invalid', 'invalid') }
    end

    def test_xrevrange_with_invalid_arguments
      assert_raises(TypeError) { r.xrevrange(nil) }
      assert_equal([], r.xrevrange(''))
    end

    def test_xlen
      r.xadd('s1', { f: 'v1' })
      r.xadd('s1', { f: 'v2' })
      assert_equal 2, r.xlen('s1')
    end

    def test_xlen_with_not_existed_key
      assert_equal 0, r.xlen('not-existed')
    end

    def test_xlen_with_invalid_key
      assert_raises(TypeError) { r.xlen(nil) }
      assert_equal 0, r.xlen('')
    end

    def test_xread_with_a_key
      r.xadd('s1', { f: 'v1' }, id: '0-1')
      r.xadd('s1', { f: 'v2' }, id: '0-2')

      actual = r.xread('s1', 0)

      assert_equal(%w(v1 v2), actual.fetch('s1').map { |i| i.last['f'] })
    end

    def test_xread_with_multiple_keys
      r.xadd('s1', { f: 'v01' }, id: '0-1')
      r.xadd('s1', { f: 'v02' }, id: '0-2')
      r.xadd('s2', { f: 'v11' }, id: '1-1')
      r.xadd('s2', { f: 'v12' }, id: '1-2')

      actual = r.xread(%w[s1 s2], %w[0-1 1-1])

      assert_equal 1, actual['s1'].size
      assert_equal 1, actual['s2'].size
      assert_equal 'v02', actual['s1'][0].last['f']
      assert_equal 'v12', actual['s2'][0].last['f']
    end

    def test_xread_with_count_option
      r.xadd('s1', { f: 'v1' }, id: '0-1')
      r.xadd('s1', { f: 'v2' }, id: '0-2')

      actual = r.xread('s1', 0, count: 1)

      assert_equal 1, actual['s1'].size
    end

    def test_xread_with_block_option
      actual = r.xread('s1', '$', block: LOW_TIMEOUT * 1000)
      assert_equal({}, actual)
    end

    def test_xread_does_not_raise_timeout_error_when_the_block_option_is_zero_msec
      prepared = false
      actual = nil
      thread = Thread.new do
        prepared = true
        actual = r.xread('s1', 0, block: 0)
      ensure
        prepared = true
      end
      Thread.pass until prepared
      r2 = init _new_client
      r2.xadd('s1', { f: 'v1' }, id: '0-1')
      thread.join(3)

      assert_equal(['v1'], actual.fetch('s1').map { |i| i.last['f'] })
    end

    def test_xread_with_invalid_arguments
      assert_raises(Valkey::CommandError) { r.xread(nil, nil) }
      assert_raises(Valkey::CommandError) { r.xread('', '') }
      assert_raises(Valkey::CommandError) { r.xread([], []) }
      assert_raises(Valkey::CommandError) { r.xread([''], ['']) }
      assert_raises(Valkey::CommandError) { r.xread('s1', '0-0', count: 'a') }
      assert_raises(Valkey::CommandError) { r.xread('s1', %w[0-0 0-0]) }
    end

    def test_xgroup_with_create_subcommand
      r.xadd('s1', { f: 'v' })
      assert_equal 'OK', r.xgroup(:create, 's1', 'g1', '$')
    end

    def test_xgroup_with_create_subcommand_and_mkstream_option
      err_msg = 'ERR The XGROUP subcommand requires the key to exist. '\
        'Note that for CREATE you may want to use the MKSTREAM option to create an empty stream automatically.'
      assert_raises(Valkey::CommandError, err_msg) { r.xgroup(:create, 's2', 'g1', '$') }
      assert_equal 'OK', r.xgroup(:create, 's2', 'g1', '$', mkstream: true)
    end

    def test_xgroup_with_create_subcommand_and_existed_stream_key
      r.xadd('s1', { f: 'v' })
      r.xgroup(:create, 's1', 'g1', '$')
      assert_raises(Valkey::CommandError, 'BUSYGROUP Consumer Group name already exists') do
        r.xgroup(:create, 's1', 'g1', '$')
      end
    end

    def test_xgroup_with_setid_subcommand
      r.xadd('s1', { f: 'v' })
      r.xgroup(:create, 's1', 'g1', '$')
      assert_equal 'OK', r.xgroup(:setid, 's1', 'g1', '0')
    end

    def test_xgroup_with_destroy_subcommand
      r.xadd('s1', { f: 'v' })
      r.xgroup(:create, 's1', 'g1', '$')
      assert_equal 1, r.xgroup(:destroy, 's1', 'g1')
    end

    def test_xgroup_with_delconsumer_subcommand
      r.xadd('s1', { f: 'v' })
      r.xgroup(:create, 's1', 'g1', '$')
      assert_equal 0, r.xgroup(:delconsumer, 's1', 'g1', 'c1')
    end

    def test_xgroup_with_invalid_arguments
      assert_raises(Valkey::CommandError) { r.xgroup(nil, nil, nil) }
      assert_raises(Valkey::CommandError) { r.xgroup('', '', '') }
    end

    def test_xreadgroup_with_a_key
      r.xadd('s1', { f: 'v1' }, id: '0-1')
      r.xgroup(:create, 's1', 'g1', '$')
      r.xadd('s1', { f: 'v2' }, id: '0-2')
      r.xadd('s1', { f: 'v3' }, id: '0-3')

      actual = r.xreadgroup('g1', 'c1', 's1', '>')

      assert_equal 2, actual['s1'].size
      assert_equal 'v2', actual['s1'][0].last['f']
      assert_equal 'v3', actual['s1'][1].last['f']
    end

    def test_xreadgroup_with_multiple_keys
      r.xadd('s1', { f: 'v01' }, id: '0-1')
      r.xgroup(:create, 's1', 'g1', '$')
      r.xadd('s2', { f: 'v11' }, id: '1-1')
      r.xgroup(:create, 's2', 'g1', '$')
      r.xadd('s1', { f: 'v02' }, id: '0-2')
      r.xadd('s2', { f: 'v12' }, id: '1-2')

      actual = r.xreadgroup('g1', 'c1', %w[s1 s2], %w[> >])

      assert_equal 1, actual['s1'].size
      assert_equal 1, actual['s2'].size
      assert_equal 'v02', actual['s1'][0].last['f']
      assert_equal 'v12', actual['s2'][0].last['f']
    end

    def test_xreadgroup_with_count_option
      r.xadd('s1', { f: 'v1' }, id: '0-1')
      r.xgroup(:create, 's1', 'g1', '$')
      r.xadd('s1', { f: 'v2' }, id: '0-2')
      r.xadd('s1', { f: 'v3' }, id: '0-3')

      actual = r.xreadgroup('g1', 'c1', 's1', '>', count: 1)

      assert_equal 1, actual['s1'].size
    end

    def test_xreadgroup_with_noack_option
      r.xadd('s1', { f: 'v1' }, id: '0-1')
      r.xgroup(:create, 's1', 'g1', '$')
      r.xadd('s1', { f: 'v2' }, id: '0-2')
      r.xadd('s1', { f: 'v3' }, id: '0-3')

      actual = r.xreadgroup('g1', 'c1', 's1', '>', noack: true)

      assert_equal 2, actual['s1'].size
    end

    def test_xreadgroup_with_block_option
      r.xadd('s1', { f: 'v' })
      r.xgroup(:create, 's1', 'g1', '$')

      actual = r.xreadgroup('g1', 'c1', 's1', '>', block: LOW_TIMEOUT * 1000)

      assert_equal({}, actual)
    end

    def test_xreadgroup_with_invalid_arguments
      assert_raises(Valkey::CommandError) { r.xreadgroup(nil, nil, nil, nil) }
      assert_raises(Valkey::CommandError) { r.xreadgroup('', '', '', '') }
      assert_raises(Valkey::CommandError) { r.xreadgroup('', '', [], []) }
      assert_raises(Valkey::CommandError) { r.xreadgroup('', '', [''], ['']) }
      r.xadd('s1', { f: 'v1' }, id: '0-1')
      r.xgroup(:create, 's1', 'g1', '$')
      assert_raises(Valkey::CommandError) { r.xreadgroup('g1', 'c1', 's1', '>', count: 'a') }
      assert_raises(Valkey::CommandError) { r.xreadgroup('g1', 'c1', 's1', %w[> >]) }
    end

    def test_xreadgroup_a_trimmed_entry
      r.xgroup(:create, 'k1', 'g1', '0', mkstream: true)
      entry_id = r.xadd('k1', { value: 'v1' })

      assert_equal({ 'k1' => [[entry_id, { 'value' => 'v1' }]] }, r.xreadgroup('g1', 'c1', 'k1', '>'))
      assert_equal({ 'k1' => [[entry_id, { 'value' => 'v1' }]] }, r.xreadgroup('g1', 'c1', 'k1', '0'))
      r.xtrim('k1', 0)

      assert_equal({ 'k1' => [[entry_id, nil]] }, r.xreadgroup('g1', 'c1', 'k1', '0'))
    end
  end
end
