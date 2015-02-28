require "shield"

class Author < Sequel::Model
  include Shield::Model

  one_to_many :images

  def self.fetch(name)
    find(:name => name)
  end
end
