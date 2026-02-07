namespace :golden_masters do
  desc "Run golden master comparison tests (detect any change in financial calculations)"
  task :verify do
    puts "Running golden master baseline tests..."
    sh "DISABLE_PARALLELIZATION=true bin/rails test test/golden_masters/"
  end

  desc "Regenerate golden master snapshots (use after intentional calculation changes)"
  task :regenerate do
    puts "Regenerating golden master snapshots..."
    sh "REGENERATE_GOLDEN_MASTERS=true DISABLE_PARALLELIZATION=true bin/rails test test/golden_masters/"
    puts "\nSnapshots regenerated. Review changes in test/golden_masters/snapshots/ before committing."
  end
end
