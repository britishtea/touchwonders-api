require "fog"
require "mini_magick"
require "stringio"

Fog.mock!

class Uploader
  CONNECTION = Fog::Storage.new({
    :provider              => "AWS",
    :aws_access_key_id     => ENV.fetch("AWS_KEY"),
    :aws_secret_access_key => ENV.fetch("AWS_SECRET"),
  })

  def self.upload!(image, name)
    new(image).upload!(name)
  end

  def initialize(image)
    @thumb = crop_and_resize(image, 50, 50)
    @full  = crop_and_resize(image, 1000, 1000)
  end

  def upload!(name)
    dir = CONNECTION.directories.create(key: "touchwonders-123", public: true)

    dir.files.create(key: "#{name}_thumb",  body: @thumb, public: true)
    dir.files.create(key: "#{name}_full",   body: @full,  public: true)
  end

  private

  def crop_and_resize(file, width, height)
    image = MiniMagick::Image.read(file)
    out   = StringIO.new ""

    image.combine_options do |c|
      c.resize  '1000x1000^'
      c.gravity 'center'
      c.extent  '1000x1000'
    end

    image.write(out)

    return out
  end
end
