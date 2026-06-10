# Copyright 2020 Google LLC
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.

require "active_record/connection_adapters/spanner_adapter"

module ActiveRecord
  module Tasks
    class SpannerDatabaseTasks
      def initialize config
        config = config.symbolize_keys
        @connection = ActiveRecordSpannerAdapter::Connection.new config
      end

      def create
        @connection.create_database
      rescue Google::Cloud::Error => error
        if error.instance_of? Google::Cloud::AlreadyExistsError
          raise ActiveRecord::DatabaseAlreadyExists
        end

        raise error
      end

      def drop
        @connection.database.drop
      end

      def purge
        begin
          drop
        rescue ActiveRecord::NoDatabaseError
          # ignored; create the database
        end

        create
      end

      def charset
        nil
      end

      def collation
        nil
      end

      # Rails 8.1 moved the protected-environment guard onto the per-adapter
      # tasks object (ActiveRecord::Tasks::AbstractTasks#check_current_protected_environment!).
      # This class predates AbstractTasks and doesn't inherit it, so DatabaseTasks
      # calls this on the Spanner tasks object and would otherwise NoMethodError.
      # Mirror the AbstractTasks implementation.
      def check_current_protected_environment! db_config, migration_class
        with_temporary_pool db_config, migration_class do |pool|
          migration_context = pool.migration_context
          current = migration_context.current_environment
          stored  = migration_context.last_stored_environment

          raise ActiveRecord::ProtectedEnvironmentError.new(stored) if migration_context.protected_environment?

          if stored && stored != current
            raise ActiveRecord::EnvironmentMismatchError.new(current: current, stored: stored)
          end
        rescue ActiveRecord::NoDatabaseError
          # No database yet — nothing to protect.
        end
      end

      def structure_dump filename, _extra_flags
        file = File.open filename, "w"
        ignore_tables = ActiveRecord::SchemaDumper.ignore_tables

        if ignore_tables.any?
          index_regx = /^CREATE(.*)INDEX(.*)ON (#{ignore_tables.join '|'})\(/
          table_regx = /^CREATE TABLE (#{ignore_tables.join '|'})/
        end

        @connection.database.ddl(force: true).each do |statement|
          next if ignore_tables.any? &&
                  (table_regx =~ statement || index_regx =~ statement)
          file.write statement
          file.write ";\n"
        end
      ensure
        file.close
      end

      def structure_load filename, _extra_flags
        statements = File.read(filename).split(";").map(&:strip).reject(&:empty?)
        ddls = statements.select { |s| s =~ /^(CREATE|ALTER|DROP|GRANT|REVOKE|ANALYZE)/ }
        @connection.execute_ddl ddls

        client = @connection.spanner.client @connection.instance_id,
                                            @connection.database_id
        dmls = statements.reject { |s| s =~ /^(CREATE|ALTER|DROP|GRANT|REVOKE|ANALYZE)/ }

        client.transaction do |tx|
          dmls.each { |dml| tx.execute_query dml }
        end
      end

      private

      # Mirrors ActiveRecord::Tasks::AbstractTasks#with_temporary_pool (Rails 8.1),
      # used by check_current_protected_environment! to inspect the migration context
      # under the target db_config without disturbing the caller's connection.
      def with_temporary_pool db_config, migration_class, clobber: false
        original_db_config = migration_class.connection_db_config
        pool = migration_class.connection_handler.establish_connection db_config, clobber: clobber

        yield pool
      ensure
        migration_class.connection_handler.establish_connection original_db_config, clobber: clobber
      end
    end

    DatabaseTasks.register_task(
      /spanner/,
      "ActiveRecord::Tasks::SpannerDatabaseTasks"
    )
  end
end
