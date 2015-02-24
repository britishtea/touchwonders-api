require "sequel"
require "pg"

DB = Sequel.connect ENV.fetch("DATABASE_URL")
