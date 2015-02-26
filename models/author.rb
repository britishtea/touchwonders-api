require "shield"

class Author < Sequel::Model
  include Shield::Model

  one_to_many :images

  def fetch(name)
    filter(:name => name)
  end
end
