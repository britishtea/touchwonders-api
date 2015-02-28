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
    set :method_override, true
    set :aws_key,     ENV.fetch("AWS_KEY")
    set :aws_secret,  ENV.fetch("AWS_SECRET")
    set :aws_server,  ENV["AWS_SERVER"] || "localhost"
    set :aws_port,    ENV["AWS_PORT"] || 4567

    require "db"
    require "models"
  end

  configure :development do
    AWS::S3::Base.establish_connection!(
      :access_key_id     => settings.aws_key, 
      :secret_access_key => settings.aws_secret,
      :server            => settings.aws_server,
      :port              => settings.aws_port,
    )
  end

  configure :production do
    AWS::S3::Base.establish_connection!(
      :access_key_id     => settings.aws_key, 
      :secret_access_key => settings.aws_secret,
    )
  end
  
  helpers do
    def require_authentication!
      author = Author[:api_key => params["api_key"]]

      if author.nil?
        halt 401, { "error" => { "messages" => ["invalid api_key"] } }.to_json
      end
    end

    def process_image!(image, name)  
      resizer = Resizer.new(image)

      ImageFile.store("#{name}_thumb", resizer.thumb, access: :public_read)
      ImageFile.store("#{name}_full", resizer.full, access: :public_read)
    end

    def fetch_image(id)
      image = Image[id]

      if image.nil?
        halt 404, { "error" => { "messages" => ["image does not exist"] } }.to_json
      end

      return image
    end

    def log_exception!
      exception = env['sinatra.error']

      logger.debug e
      logger.debug e.backtrace
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
      image        = Image.create(validator.attributes)
      image.author = Author[:api_key => params[:api_key]]

      params[:tag].each do |name|
        tag = Tag.find_or_create(name: name)
        image.add_tag tag
      end

      process_image!(image_file, image.file_hash)

      status  201
      headers "Location" => url("/image/#{image.id}")
      
      { "response" => { "id" => image.id } }.to_json
    rescue Sequel::ValidationFailed
      halt 400, { "error" => { "messages" => ["image: duplicate"] } }.to_json
    end
  end

  get "/image/:id" do |id|
    image = fetch_image(id)

    headers "Last-Modified" => image.updated_at.to_s
    
    {
      "response" => {
        "id"     => image.id,
        "title"  => image.title,
        "author" => image.author ? image.author.name : nil,
        "thumb"  => url("/thumb/#{image.file_hash}"),
        "full"   => url("/full/#{image.file_hash}"),
        "tags"   => image.tags.map(&:name),
      }
    }.to_json
  end

  put "/image/:id" do |id|
    require_authentication!

    image = fetch_image(id)

    image.title = params["title"]
    image.remove_all_tags

    params["tag"].each do |tag|
      image.add_tag Tag.find_or_create(:name => tag) unless tag.empty?
    end

    image.save

    status  204
    headers "Last-Modified" => image.updated_at.to_s
  end

  delete "/image/:id" do |id|
    require_authentication!

    image = fetch_image(id)

    ImageFile.delete("#{image.file_hash}_thumb")
    ImageFile.delete("#{image.file_hash}_full")

    image.remove_all_tags
    image.destroy

    status 204
  end

  get "/thumb/:hash" do |hash|
    status  301
    headers "Location" => ImageFile.url_for("#{hash}_thumb", authenticated: false)
  end

  get "/full/:hash" do |hash|
    status 301
    headers "Location" => ImageFile.url_for("#{hash}_full", authenticated: false)  
  end

  get "/images" do
    if params.key?("tag")
      tag = Tag[:name => params["tag"]]

      if tag.nil?
        images = []
      else
        images = tag.images_dataset.order(:created_at).last(25)
      end
    else
      images = Image.order(:created_at).last(25)
    end

    images = images.map do |image|
      {
        "id"     => image.id,
        "title"  => image.title,
        "author" => image.author ? image.author.name : nil,
        "thumb"  => url("/thumb/#{image.file_hash}"),
        "full"   => url("/full/#{image.file_hash}"),
        "tags"   => image.tags.map(&:name),
      }
    end

    { "response" => images }.to_json
  end
  get "/api_key" do
    author = Author.authenticate(params["name"], params["password"])

    if author.nil?
      error 401, { "error" => { "messages" => ["invalid credentials"] } }.to_json
    end

    { "response" => { "api_key" => author.api_key } }.to_json
  end

  error Sequel::Error do
    log_exception!

    status 504
    { "error" => { "messages" => ["database error"] } }.to_json
  end

  error AWS::S3::S3Exception do
    log_exception!

    status 504
    { "error" => { "messages" => ["storage error"] } }.to_json
  end
end
