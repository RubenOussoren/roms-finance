class Demo::Generator
  def initialize(seed: nil)
    # Seed is accepted for API compatibility but no longer used —
    # the seed files use their own deterministic RNG (Random.new(42)).
    @seed = seed
  end

  attr_reader :seed

  # Full realistic demo data: clears everything, then loads all seed files.
  def generate_default_data!(skip_clear: false, email: nil)
    unless skip_clear
      puts "Clearing existing data..."
      clear_all_data!
    end

    puts "Loading seed files..."
    load_seed_files!
    puts "Demo data loaded successfully!"
  end

  # Empty family — onboarded, no financial data.
  def generate_empty_data!(skip_clear: false)
    unless skip_clear
      puts "Clearing existing data..."
      clear_all_data!
    end

    create_minimal_family!(onboarded: true, subscribed: true)
    puts "Empty demo data loaded successfully!"
  end

  # New user family — not onboarded, no financial data.
  def generate_new_user_data!(skip_clear: false)
    unless skip_clear
      puts "Clearing existing data..."
      clear_all_data!
    end

    create_minimal_family!(onboarded: false, subscribed: false)
    puts "New user demo data loaded successfully!"
  end

  private

    def clear_all_data!
      if Family.count > 50
        raise "Too much data to clear (#{Family.count} families). Run 'rails db:reset' instead."
      end
      Demo::DataCleaner.new.destroy_everything!
    end

    def load_seed_files!
      Dir[Rails.root.join("db", "seeds", "*.rb")].sort.each { |f| load f }
    end

    def create_minimal_family!(onboarded:, subscribed:)
      family = Family.create!(
        name: "The Morrison Family",
        currency: "CAD",
        country: "CA",
        locale: "en",
        timezone: "America/Toronto",
        date_format: "%Y-%m-%d"
      )

      family.create_subscription!(
        status: "trialing",
        trial_ends_at: 1.year.from_now
      ) if subscribed

      family.users.create!(
        email: "admin@roms.local",
        first_name: "James",
        last_name: "Morrison",
        role: "admin",
        password: "password",
        onboarded_at: onboarded ? 2.years.ago : nil
      )

      family.users.create!(
        email: "member@roms.local",
        first_name: "Sarah",
        last_name: "Morrison",
        role: "member",
        password: "password",
        onboarded_at: onboarded ? 2.years.ago : nil
      )

      family
    end
end
