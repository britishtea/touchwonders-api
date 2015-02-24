Sequel.migration do
  change do
    create_table(:authors) do
      primary_key :id
      String      :name, :unique => true
      String      :crypted_password
      String      :api_key
    end

    create_table(:images) do
      primary_key :id
      String      :title
      String      :file_hash, :unique => true
      foreign_key :author_id, :authors, :null => true
      DateTime    :created_at
      DateTime    :updated_at
    end

    create_table(:tags) do
      primary_key :id
      String      :name, :unique => true
    end

    create_join_table(:image_id => :images, :tag_id => :tags)
  end
end
