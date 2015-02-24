$:.unshift File.expand_path('../../', __FILE__)
$:.unshift File.expand_path('../../lib', __FILE__)

def setup_database!
  migrations_path = File.expand_path('../../migrations', __FILE__)

  Sequel.extension(:migration)
  Sequel::Migrator.run(DB, migrations_path)
end
