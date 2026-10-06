require "test_helper"
require_relative "autonomy_schema_guard"

class AutonomySchemaGuardTest < ActiveSupport::TestCase
  setup { AutonomySchemaGuard.install! }
  test "maintenance checks fingerprints without invoking automatic preparation" do
    maintenance = Object.new
    maintenance.extend(AutonomySchemaMaintenance)
    maintenance.define_singleton_method(:check_pending_migrations) { }
    configs = ActiveRecord::Base.configurations.configs_for(env_name: "test")
    configs.each { |config| ActiveRecord::Tasks::DatabaseTasks.expects(:schema_up_to_date?).with(config).returns(false) }
    ActiveRecord::Tasks::DatabaseTasks.expects(:reconstruct_from_schema).never
    error = assert_raises(RuntimeError) { maintenance.maintain_test_schema! }
    assert_includes error.message, "refuses automatic schema preparation"
  end

  test "matching fingerprint is allowed without preparation" do
    maintenance = Object.new
    maintenance.extend(AutonomySchemaMaintenance)
    maintenance.define_singleton_method(:check_pending_migrations) { }
    ActiveRecord::Tasks::DatabaseTasks.stubs(:schema_up_to_date?).returns(true)
    ActiveRecord::Tasks::DatabaseTasks.expects(:reconstruct_from_schema).never
    maintenance.maintain_test_schema!
  end

  test "installed guards retain interception after Rails initialization" do
    assert_equal AutonomySchemaMaintenance, ActiveRecord::Migration.method(:maintain_test_schema!).owner
    assert_equal AutonomySchemaMaintenance, ActiveRecord::Migration.method(:load_schema_if_pending!).owner
    assert_equal AutonomyDatabasePreparation, ActiveRecord::Tasks::DatabaseTasks.method(:structure_load).owner
    ActiveRecord::Tasks::DatabaseTasks.expects(:database_adapter_for).never
    with_env_overrides AUTONOMY_PREPARE_APPROVED: nil do
      assert_raises(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.structure_load(Object.new) }
      assert_raises(RuntimeError) { ActiveRecord::Tasks::DatabaseTasks.truncate_all }
    end
  end

  test "pending migrations fail before fingerprint checks or preparation" do
    ActiveRecord::Migration.expects(:check_pending_migrations).raises(ActiveRecord::PendingMigrationError)
    ActiveRecord::Tasks::DatabaseTasks.expects(:schema_up_to_date?).never
    ActiveRecord::Tasks::DatabaseTasks.expects(:reconstruct_from_schema).never
    assert_raises(ActiveRecord::PendingMigrationError) { ActiveRecord::Migration.maintain_test_schema! }
  end

  test "direct preparation calls fail before invoking database tasks" do
    preparation = Object.new
    preparation.extend(AutonomyDatabasePreparation)
    with_env_overrides AUTONOMY_PREPARE_APPROVED: nil do
      %i[create drop purge reconstruct_from_schema load_schema structure_load truncate_all truncate_tables].each do |operation|
        error = assert_raises(RuntimeError) { preparation.public_send(operation, Object.new) }
        assert_includes error.message, "requires separate approval"
      end
    end
  end
end
