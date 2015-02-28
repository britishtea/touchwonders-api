require_relative "api_helper"

test "list images" do
  get "/images"

  assert_equal 200, last_response.status
  assert_equal 1, JSON.parse(last_response.body)["response"].size
end

test "list images with non-existing tag" do
  get "/images", "tag" => "xxx"

  assert_equal 200, last_response.status
  assert_equal 0, JSON.parse(last_response.body)["response"].size
end

test "list images with existing tag" do
  get "/images", "tag" => "cat"

  assert_equal 200, last_response.status
  assert_equal 1, JSON.parse(last_response.body)["response"].size  
end
