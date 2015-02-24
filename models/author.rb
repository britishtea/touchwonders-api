class Author < Sequel::Model
  include Shield::Model

  one_to_many :images

  def fetch(email_address)
    filter(:email_address => email_address)
  end
end
