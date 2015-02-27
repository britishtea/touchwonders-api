require_relative "../test_helper"
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

def file(file_name, type)
  file = File.new(File.expand_path("../#{file_name}", __FILE__))

  Rack::Test::UploadedFile.new(file, type)
end

# CREATE

test "missing fields" do
  post "/image", {}

  expected = {
    "error" => {
      "messages" => ["title: not_present", "image: not_present"]
    } 
  }

  assert_equal 400, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "invalid image" do
  post "/image", "title" => "title", 
                 "tag[]" => "cat",
                 "image" => file("gif.gif", "image/gif")

  expected = {
    "error" => {
      "messages" => ["image: invalid_format"],
    }
  }

  assert_equal 400, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "duplicate image" do
  post "/image", "title" => "title",
                 "tag[]" => "cat",
                 "image" => file("duplicate.jpg", "image/jpg")
  post "/image", "title" => "title",
                 "tag[]" => "cat",
                 "image" => file("duplicate.jpg", "image/jpg")

  expected = {
    "error" => {
      "messages" => ["image: duplicate"],
    }
  }

  assert_equal 400, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "valid image" do
  post "/image", "title" => "title",
                 "tag[]" => "cat",
                 "image" => file("jpeg.jpg", "image/jpg")

  assert_equal 201, last_response.status
  assert last_response["Location"]

  image = Image[:title => "title"]

  assert image
  assert_equal ["cat"], image.tags.map(&:name)
end


# READ

test "non-existing image" do
  get "/image/xxx"

  expected = {
    "error" => {
      "message" => "image does not exist"
    }
  }

  assert_equal 404, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "existing image" do
  get "/image/1"

  assert_equal 200, last_response.status

  response = JSON.parse(last_response.body)["response"]

  assert_equal 1, response["id"]
  assert_equal "title", response["title"]
  assert_equal "jip", response["author"]
  assert_equal ["cat"], response["tags"]
  assert response["thumb"].end_with?("/thumb/hash")
  assert response["full"].end_with?("/full/hash")
end


# UPDATE

test "non-existing image" do
  put "/image/xxx", "title" => "new title", "tag[]" => "new tag"

  expected = {
    "error" => {
      "message" => "image does not exist"
    }
  }

  assert_equal 404, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "existing image" do
  put "/image/1", "title" => "new title", "tag[]" => "new tag"

  assert_equal 204, last_response.status
  assert_equal "new title", Image[1].title
  assert Image[1].tags.find { |tag| tag.name == "new tag" }
end


# DELETE

test "non-existing image" do
  delete "/image/xxx"

  expected = {
    "error" => {
      "message" => "image does not exist"
    }
  }

  assert_equal 404, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "existing image" do
  delete "/image/1"

  assert_equal 204, last_response.status
  assert_equal nil, Image[1]
end
