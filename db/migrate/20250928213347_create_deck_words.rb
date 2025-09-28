class CreateDeckWords < ActiveRecord::Migration[8.0]
  def change
    create_table :deck_words do |t|
      t.references :deck, null: false, foreign_key: true
      t.references :word, null: false, foreign_key: true

      t.timestamps
    end

    add_index :deck_words, [:deck_id, :word_id], unique: true
  end
end
