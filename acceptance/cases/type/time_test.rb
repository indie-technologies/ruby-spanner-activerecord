# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

# frozen_string_literal: true

require "test_helper"

module ActiveRecord
  module Type
    class TimeTest < SpannerAdapter::TestCase
      include SpannerAdapter::Types::TestHelper

      def test_convert_to_sql_type
        assert_equal "TIMESTAMP", connection.type_to_sql(:time)
      end

      def test_assign_time
        expected_time = ::Time.now
        record = TestTypeModel.new start_time: expected_time

        assert_equal expected_time, record.start_time
      end

      def test_assign_empty_time
        record = TestTypeModel.new start_time: ""
        assert_nil record.start_time
      end

      def test_assign_nil_time
        record = TestTypeModel.new start_time: nil
        assert_nil record.start_time
      end

      def test_set_and_save_time
        expected_time = ::Time.now.utc
        record = TestTypeModel.create! start_time: expected_time

        assert_equal expected_time, record.start_time

        record.reload
        assert_equal expected_time, record.start_time
      end

      def test_date_time_string_value_with_subsecond_precision
        expected_time = ::Time.local 2017, 07, 4, 14, 19, 10, 897761

        string_value = "2017-07-04 14:19:10.897761"

        record = TestTypeModel.new start_time: string_value
        assert_equal expected_time, record.start_time.utc

        record.save!
        assert_equal expected_time, record.start_time.utc

        assert_equal record, TestTypeModel.find_by(start_time: string_value)
      end

      def test_date_time_with_string_value_with_non_iso_format
        string_value = "04/07/2017 2:19pm"
        expected_time = ::Time.local 2017, 07, 4, 14, 19

        record = TestTypeModel.new start_time: string_value
        assert_equal expected_time, record.start_time

        record.save!
        assert_equal expected_time, record.start_time.utc

        assert_equal record, TestTypeModel.find_by(start_time: string_value)
      end

      def test_multiparameter_assignment_preserves_date
        expected_time = ::Time.utc(2026, 9, 9, 10, 30, 0)
        record = TestTypeModel.new start_time: { 1 => 2026, 2 => 9, 3 => 9, 4 => 10, 5 => 30 }

        assert_equal expected_time, record.start_time

        record.save!
        record.reload

        assert_equal expected_time, record.start_time
      end
    end
  end
end