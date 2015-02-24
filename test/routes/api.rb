require_relative "../test_helper"
require "rack/test"
require "routes/api"

include Rack::Test::Methods

def app
  API
end

setup_database!

$file_hash = app.file_hash(File.expand_path("duplicate.jpg", __FILE__))

DB[:authors].insert(id: 1, name: "jip", password: "hunter2", api_key: "123456")
DB[:tags].insert(id: 1, name: "cat")
DB[:images].insert(id: 1, title: "title", file_hash: $file_hash, author_id: 1)
DB[:images_tags].insert(image_id: 1, tag_id: 1)

# CREATE

test "missing fields" do
  post "/api/image"

  expected = {
    "error" => {
      "message": "missing fields: title, image",
    } 
  }

  assert_equal "400", last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "invalid image" do
  post "/api/image", "title" => "title", 
                     "tag[]" => "cat",
                     "image" => Rack::Test::UploadedFile.new("gif.gif", "image/gif")

  expected = {
    "error": {
      "message": "invalid image format",
    }
  }

  assert_equal "400", last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "duplicate image" do
  post "/api/image", "title" => "title",
                     "tag[]" => "cat",
                     "image" => Rack::Test::UploadedFile.new("duplicate.png", "image/png")

  expected = {
    "error": {
      "message": "duplicate image",
    }
  }

  assert_equal "400", last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "valid image" do
  post "/api/image", "title" => "title",
                     "tag[]" => "cat",
                     "image" => Rack::Test::UploadedFile.new("jpeg.jpg", "image/jpg")

  expected = {
    "response" => {
      "href" => "/api/image/",
    }
  }

  assert_equal "201", last_response.status
  assert last_response["Location"].start_with? "/api/image/"
  assert_equal expected, JSON.parse(last_response.body)
end


# READ

test "non-existing image" do
  get "/api/image/xxx"

  expected = {
    "error" => {
      "message" => "image does not exist"
    }
  }

  assert_equal "404", last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "existing image" do
  get "/api/image/1"

  expected = {
    "response" => {
      "id"        => 1,
      "title"     => "title",
      "thumbnail" => "/images/#{$file_hash}_thumbnail.png",
      "full_size" => "/images/#{$file_hash}_thumbnail.png",
      "tags"      => ["cat"],
    }
  }

  assert_equal "200",  last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end


# UPDATE

test "non-existing image" do
  put "/api/image/xxx", "title" => "new title", "tag[]" => "new tag"

  expected = {
    "error" => {
      "message" => "image does not exist"
    }
  }

  assert_equal "404", last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "existing image" do
  put "/api/image/1", "title" => "new title", "tag[]" => "new tag"

  assert_equal "204", last_response.status
end


# DELETE

test "non-existing image" do
  delete "/api/image/xxx"

  expected = {
    "error" => {
      "message" => "image does not exist"
    }
  }

  assert_equal "404", last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "existing image" do
  delete "/api/image/1"

  assert_equal "204", last_response.status
end
