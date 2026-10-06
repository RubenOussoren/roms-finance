module AutonomySchemaMaintenance
  def maintain_test_schema!
    load_schema_if_pending!
  end

  def load_schema_if_pending!
    check_pending_migrations
    configs = ActiveRecord::Base.configurations.configs_for(env_name: "test")
    unless configs.all? { |config| ActiveRecord::Tasks::DatabaseTasks.schema_up_to_date?(config) }
      raise "Autonomy refuses automatic schema preparation: schema fingerprint mismatch requires supervised reconciliation"
    end
  end
end

module AutonomyDatabasePreparation
  %i[create drop purge reconstruct_from_schema load_schema structure_load truncate_all truncate_tables].each do |operation|
    define_method(operation) do |*args, **kwargs|
      unless ENV["AUTONOMY_PREPARE_APPROVED"] == "bootstrap-2026-10"
        raise "Autonomy refuses database preparation: #{operation} requires separate approval"
      end
      super(*args, **kwargs)
    end
  end
end

module AutonomySchemaGuard
  def self.install!
    ActiveRecord::Migration.singleton_class.prepend(AutonomySchemaMaintenance) unless ActiveRecord::Migration.singleton_class < AutonomySchemaMaintenance
    ActiveRecord::Tasks::DatabaseTasks.singleton_class.prepend(AutonomyDatabasePreparation) unless ActiveRecord::Tasks::DatabaseTasks.singleton_class < AutonomyDatabasePreparation
  end
end
