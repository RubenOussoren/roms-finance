namespace :demo_data do
  desc "Load empty demo dataset (no financial data)"
  task empty: :environment do
    start = Time.now
    puts "Loading EMPTY demo data..."

    Demo::Generator.new.generate_empty_data!

    puts "Done in #{(Time.now - start).round(2)}s"
  end

  desc "Load new-user demo dataset (family created but not onboarded)"
  task new_user: :environment do
    start = Time.now
    puts "Loading NEW-USER demo data..."

    Demo::Generator.new.generate_new_user_data!

    puts "Done in #{(Time.now - start).round(2)}s"
  end

  desc "Load full realistic demo dataset"
  task default: :environment do
    start = Time.now
    puts "Loading FULL demo data..."

    Demo::Generator.new.generate_default_data!

    validate_demo_data

    elapsed = Time.now - start
    puts "Demo data ready in #{elapsed.round(2)}s"
  end

  # ---------------------------------------------------------------------------
  # Validation helpers
  # ---------------------------------------------------------------------------
  def validate_demo_data
    total_entries   = Entry.count
    trade_entries   = Entry.where(entryable_type: "Trade").count
    categorized_txn = Transaction.joins(:category).count
    txn_total       = Transaction.count

    coverage = txn_total > 0 ? ((categorized_txn.to_f / txn_total) * 100).round(1) : 0

    puts "\nValidation Summary".ljust(40, "-")
    puts "Entries total:              #{total_entries}"
    puts "Trade entries:              #{trade_entries}"
    puts "Txn categorization:         #{coverage}%"

    unless total_entries.between?(2_000, 6_000)
      puts "WARNING: Total entries #{total_entries} outside 2k-6k range"
    end
  end
end
