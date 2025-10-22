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
  end
end
