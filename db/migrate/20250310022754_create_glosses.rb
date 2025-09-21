class CreateGlosses < ActiveRecord::Migration[8.0]
  def change
    create_table :glosses do |t|
      t.text :text, null: false
      t.references :word, null: false, foreign_key: true

      t.timestamps
    end
  end
end
