require "bundler/setup"
require "sinatra"
require "aws/s3"
require "json"

require "validators/image"
require "resizer"

class ImageFile < AWS::S3::S3Object
  set_current_bucket_to "touchwonders-jip"
end

class API < Sinatra::Base
  configure do
    set :environment, ENV.fetch("ENVIRONMENT", "development")

    require "db"
    require "models"

    AWS::S3::Base.establish_connection!(
      :access_key_id     => "123", 
      :secret_access_key => "abc",
      :server            => "0.0.0.0",
      :port              => 4567,
    )
  end
  
  helpers do
    def require_authentication!
    end

    def require_fields(params, *fields, &error)
      missing = fields.reject { |field| params.key?(field) }

      unless missing.empty?
        yield(missing)
      end
    end

    def process_image!(image, name)  
      resizer = Resizer.new(image)

      ImageFile.store("#{name}_thumb", resizer.thumb, access: :public_read)
      ImageFile.store("#{name}_full", resizer.full, access: :public_read)
    end
  end

  post "/image" do
    require_authentication!

    image_file = params.fetch("image", {})[:tempfile]
    validator  = Validators::Image.new(title: params["title"], image: image_file)

    unless validator.valid?
      halt 400, {
        "error" => { 
          "messages" => validator.errors.map { |field, *errors|
            "#{field}: #{errors.join(", ")}"
          }
        }
      }.to_json
    end

    begin
      image = Image.create(validator.attributes)

      params[:tag].each do |name|
        tag = Tag.find_or_create(name: name)
        image.add_tag tag
      end

      process_image!(image_file, image.file_hash)

      status  201
      headers "Location" => url("/image/#{image.id}")
    rescue Sequel::ValidationFailed
      halt 400, { "error" => { "messages" => ["image: duplicate"] } }.to_json
    rescue 
      halt 500
    end
  end

  get "/image/:id" do |id|
    image = Image[id]

    if image.nil?
      halt 404, { "error" => { "message" => "image does not exist" } }.to_json
    end

    headers "Last-Modified" => image.updated_at.to_s
    
    {
      "response" => {
        :id     => image.id,
        :title  => image.title,
        :author => image.author.name,
        :thumb  => url("/thumb/#{image.file_hash}"),
        :full   => url("/full/#{image.file_hash}"),
        :tags   => image.tags.map(&:name),
      }
    }.to_json
  end

  put "/image/:id" do |id|
    require_authentication!

    image = Image[id]

    if image.nil?
      halt 404, { "error" => { "message" => "image does not exist" } }.to_json
    end

    begin
      image.title = params["title"]

      params["tag"].each do |tag|
        image.add_tag Tag.find_or_create(:name => tag)
      end

      image.save
    rescue
      halt 500
    end

    status  204
    headers "Last-Modified" => image.updated_at.to_s
  end

  delete "/image/:id" do |id|
    require_authentication!

    image = Image[id]

    if image.nil?
      halt 404, { "error" => { "message" => "image does not exist" } }.to_json
    end

    begin
      ImageFile.delete("#{image.file_hash}_thumb")
      ImageFile.delete("#{image.file_hash}_full")

      image.remove_all_tags
      image.destroy
    rescue 
      halt 500
    end

    status 204
  end

  error do |e|
    puts e, e.backtrace.first(10)
  end
end
