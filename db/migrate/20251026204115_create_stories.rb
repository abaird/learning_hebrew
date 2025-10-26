class CreateStories < ActiveRecord::Migration[8.0]
  def change
    create_table :stories do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.jsonb :content, null: false, default: {}

      t.timestamps
    end

    add_index :stories, :slug, unique: true
    add_index :stories, :content, using: :gin
  end
end
