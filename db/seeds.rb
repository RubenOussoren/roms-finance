# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts 'Run the following command to create demo data: `rake demo_data:default`' if Rails.env.development?

Dir[Rails.root.join('db', 'seeds', '*.rb')].sort.each do |file|
  basename = File.basename(file)

  # Seeds 10+ are demo data — skip in production
  if Rails.env.production? && basename.match?(/\A(?:1\d|[2-9]\d|\d{3,})_/)
    puts "Skipping demo seed in production: #{basename}"
    next
  end

  puts "Loading seed file: #{basename}"
  require file
end
