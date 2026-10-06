# Only the approved disposable upgrade; never a general migration entry point.
abort "Explicit issue-145 migration approval required" unless ENV["AUTONOMY_MIGRATE_APPROVED"] == "issue-145"
abort "Isolated test target required" unless ENV["RAILS_ENV"] == "test" && ENV["POSTGRES_DB"] == "roms_autonomy_test" && ENV["DB_HOST"] == "db"
require_relative "../config/environment"

baseline = 20260420120000
versions = (20261006030000..20261006030003).to_a
pool = ActiveRecord::Base.connection_pool
context = pool.migration_context
known = context.migrations.map(&:version)
installed = context.get_all_versions
abort "Unknown installed migration version" unless (installed - known).empty?
pending = context.migrations.reject { |migration| installed.include?(migration.version) }.map(&:version)
abort "Unexpected baseline or partial migration; supervised reconciliation required" unless installed.max == baseline && pending == versions

pool.with_connection do |connection|
  marker = connection.select_value("SELECT shobj_description(oid, 'pg_database') FROM pg_database WHERE datname = current_database()")
  abort "Disposable database ownership mismatch" unless marker == "ROMS autonomy disposable bootstrap-2026-10 synthetic only"
  connection.execute("SET lock_timeout = '5s'")
  connection.execute("SET statement_timeout = '120s'")

  # Rails commits each migration separately, respecting disable_ddl_transaction!.
  context.up(versions.last)
end
abort "Unexpected migrated versions" unless (context.get_all_versions - installed).sort == versions
File.open(Rails.root.join("db/schema.rb"), "w") { |file| ActiveRecord::SchemaDumper.dump(pool, file) }
# Keep Rails' fingerprint coherent; the test guard still fails closed on mismatch.
pool.internal_metadata[:schema_sha1] = Digest::SHA1.hexdigest(File.binread(Rails.root.join("db/schema.rb")))
puts "Issue145 upgrade settled: exactly four approved migrations; schema captured."
