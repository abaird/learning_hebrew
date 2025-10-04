class CreatePartOfSpeechCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :part_of_speech_categories do |t|
      t.string :name, null: false
      t.string :abbrev, null: false

      t.timestamps
    end

    add_index :part_of_speech_categories, :name, unique: true
    add_index :part_of_speech_categories, :abbrev, unique: true
  end
end
