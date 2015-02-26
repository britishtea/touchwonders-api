require "scrivener"

module Validators
  class Image < Scrivener
    attr_accessor :title, :image

    def validate
      assert_present :title

      if assert_present :image
        assert_image :image
      end
    end

    private

    def assert_image(att, error = [att, :invalid_format])
      header = send(att).read(11).force_encoding("BINARY")

      assert png?(header) || jpg?(header), error
    end

    def png?(header)
      header.start_with?("\x89PNG\r\n\x1A\n".force_encoding("BINARY"))
    end

    def jpg?(header)
      unless header.start_with?("\xFF\xD8\xFF".force_encoding("BINARY"))
        return false
      end

      jfif = Regexp.new("^(\xE0|\xE1)..JFIF\x00".force_encoding("BINARY"))
      exif = Regexp.new("^(\xE0|\xE1)..EXIF".force_encoding("BINARY"))

      jfif =~ header[3..-1] || exif =~ header[3..-1]
    end
  end
end
