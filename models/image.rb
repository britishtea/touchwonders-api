require "digest/sha1"

class Image < Sequel::Model
  many_to_one  :author
  many_to_many :tags

  plugin :validation_helpers

  def image=(file)
    self.file_hash = ::Digest::SHA1.hexdigest(file.read)
  end

  def validate
    super

    validates_presence [:title, :file_hash], message: "missing field"
    validates_unique :file_hash
  end

  def before_create
    self.created_at = Time.now

    super
  end

  def before_save
    self.updated_at = Time.now

    super
  end
end
