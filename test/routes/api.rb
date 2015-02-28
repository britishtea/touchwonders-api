require_relative "api_helper"
require "db"

def file(file_name, type)
  file = File.new(File.expand_path("../#{file_name}", __FILE__))

  Rack::Test::UploadedFile.new(file, type)
end

# CREATE

test "unauthenticated" do
  post "/image", {}

  expected = { "error" => { "messages" => ["invalid api_key"] } }

  assert_equal 401, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "missing fields" do
  post "/image", { "api_key" => "123456" }

  expected = {
    "error" => {
      "messages" => ["title: not_present", "image: not_present"]
    } 
  }

  assert_equal 400, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "invalid image" do
  post "/image", "api_key" => "123456",
                 "title" => "title", 
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
  post "/image", "api_key" => "123456",
                 "title" => "title",
                 "tag[]" => "cat",
                 "image" => file("duplicate.jpg", "image/jpg")
  post "/image", "api_key" => "123456",
                 "title" => "title",
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
  post "/image", "api_key" => "123456",
                 "title" => "title",
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
      "messages" => ["image does not exist"]
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

test "unauthenticated" do
  put "/image/1", {}

  expected = { "error" => { "messages" => ["invalid api_key"] } }

  assert_equal 401, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "non-existing image" do
  put "/image/xxx", "api_key" => "123456",
                    "title" => "new title",
                    "tag[]" => "new tag"

  expected = {
    "error" => {
      "messages" => ["image does not exist"]
    }
  }

  assert_equal 404, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "existing image" do
  put "/image/1", "api_key" => "123456",
                  "title" => "new title",
                  "tag[]" => "new tag"

  assert_equal 204, last_response.status
  assert_equal "new title", Image[1].title
  assert Image[1].tags.find { |tag| tag.name == "new tag" }
end


# DELETE

test "unauthenticated" do
  delete "/image/1", {}

  expected = { "error" => { "messages" => ["invalid api_key"] } }

  assert_equal 401, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "non-existing image" do
  delete "/image/xxx", { "api_key" => "123456" }

  expected = {
    "error" => {
      "messages" => ["image does not exist"]
    }
  }

  assert_equal 404, last_response.status
  assert_equal expected, JSON.parse(last_response.body)
end

test "existing image" do
  delete "/image/1", "api_key" => "123456"

  assert_equal 204, last_response.status
  assert_equal nil, Image[1]
end
