require "bundler/setup"
require "sinatra"
require "sequel"
require "pg"
require "db"
require "models"
require "digest/sha1"
require "json"
require "validators/image"
require "uploader"

class API < Sinatra::Base
  configure {
    set :environment, "development"
  }
  
  helpers do
    def require_authentication!
    end

    def require_fields(params, *fields, &error)
      missing = fields.reject { |field| params.key?(field) }

      unless missing.empty?
        yield(missing)
      end
    end

    def process_image!(image, file_name)
      Uploader.upload!(image, file_name)
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
        :id        => image.id,
        :title     => image.title,
        :author    => image.author.name,
        :thumbnail => url("/images/#{image.file_hash}_thumb"),
        :full_size => url("/images/#{image.file_hash}_full"),
        :tags      => image.tags.map(&:name),
      }
    }.to_json
  end

  put "/image/:id" do |id|
    require_authentication!

    image = Image[id]

    if image.nil?
      halt 404, { "error" => { "message" => "image does not exist" } }.to_json
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

    image.remove_all_tags
    image.destroy

    status 204
  end

  error do |e|
    puts e, e.backtrace.first(10)
  end
end
