# Copyright 2021 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  module Type
    class DateTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "JSON", connection.type_to_sql(:json)
      end

      def test_set_json
        expected_hash = {"key"=>"value", "array_key"=>%w[value1 value2]}
        record = TestTypeModel.new details: {key: "value", array_key: %w[value1 value2]}

        assert_equal expected_hash, record.details

        record.save!
        record.reload
        assert_equal expected_hash, record.details
      end

      def test_write_json
        record = TestTypeModel.new details: "{\"this is a string (which is valid json), that happens to contain an valid encoded JSON object\":\"\"}"
        record.save!
        record.reload

        # fails, with {"key"=>"this is a string (which is valid json), that happens to contain an encoded JSON object"}
        # I can see how this expectation is desirable, yet not true to the JSON spec.
        assert_equal "{\"this is a string (which is valid json), that happens to contain an valid encoded JSON object\":\"\"}", record.details
      end

      def test_float_serialization
        record = TestTypeModel.create! details: { test: 41.021725 }
        record.reload

        assert_equal 41.021725, record.details[:test]
      end
    end
  end
end
