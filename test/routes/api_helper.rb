require_relative "../test_helper"

ENV["DATABASE_URL"] = "sqlite::memory:"

require "db"

setup_database!

DB[:authors].insert(id: 1, name: "jip", api_key: "123456")
DB[:tags].insert(id: 1, name: "cat")
DB[:images].insert(id: 1, title: "title", file_hash: "hash", author_id: 1, 
  created_at: Time.now, updated_at: Time.now)
DB[:images_tags].insert(image_id: 1, tag_id: 1)

require "rack/test"
require "routes/api"

extend Rack::Test::Methods

def app
  API
end
