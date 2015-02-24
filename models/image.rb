class Image < Sequel::Model
  many_to_one  :authors
  many_to_many :tags

  def before_create
    self.created_at = Time.now

    super
  end

  def before_save
    self.updated_at = Time.now

    super
  end
end
