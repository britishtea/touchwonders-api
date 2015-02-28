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

    if image.width > image.height
      image.shave "#{(image.width - image.height) / 2}x0"
    elsif image.height > image.width
      image.shave "0x#{(image.height - image.width) / 2}"
    end

    image.resize "#{width}x#{height}!"

    image.write(out)
    out.rewind
    out.close_write

    return out
  end
end
