class CreateWords < ActiveRecord::Migration[8.0]
  def change
    create_table :words do |t|
      t.string :representation, null: false
      t.string :part_of_speech, null: false
      t.text :mnemonic
      t.string :pronunciation_url
      t.string :picture_url
      t.references :deck, null: false, foreign_key: true

      t.timestamps
    end
  end
end
