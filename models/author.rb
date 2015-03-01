require "shield"
require "securerandom"

class Author < Sequel::Model
  include Shield::Model

  one_to_many :images

  def self.fetch(name)
    find(:name => name)
  end

  def before_save
    super

    self.api_key = SecureRandom.base64(32)
  end
end
