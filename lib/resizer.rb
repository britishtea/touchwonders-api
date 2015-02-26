require "mini_magick"
require "stringio"

class Resizer
  def initialize(image)
    @image = image
  end

  def thumb
    crop_and_resize(@image, 50, 50)
  end

  def full
    crop_and_resize(@image, 1000, 1000)
  end

  private

  def crop_and_resize(file, width, height)
    image = MiniMagick::Image.read(file)
    out   = StringIO.new ""

    image.resize "#{width}x#{height}^"

    if image.width > image.height
      image.shave "#{(image.width - image.height) / 2}"
    elsif image.height > image.width
      image.shave "x#{(image.height - image.width) / 2}"
    end

    image.write(out)

    return out.close_write
  end
end
