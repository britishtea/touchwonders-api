require_relative "api_helper"

ImageFile.store("hash_thumb", open(__FILE__))
ImageFile.store("hash_full", open(__FILE__))

at_exit do
  ImageFile.delete("hash_thumb")
  ImageFile.delete("hash_full")
end

test "thumbnail image" do
  get "/thumb/hash"

  assert_equal 301, last_response.status
end

test "full size image" do
  get "/full/hash"

  assert_equal 301, last_response.status
end
