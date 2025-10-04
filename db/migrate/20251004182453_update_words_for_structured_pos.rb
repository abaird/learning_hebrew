class UpdateWordsForStructuredPos < ActiveRecord::Migration[8.0]
  def change
    # Add foreign keys for structured POS (all optional)
    add_reference :words, :part_of_speech_category, foreign_key: true, null: true
    add_reference :words, :gender, foreign_key: true, null: true
    add_reference :words, :verb_form, foreign_key: true, null: true

    # Add cached display column
    add_column :words, :pos_display, :string

    # Remove old part_of_speech string column
    remove_column :words, :part_of_speech, :string
  end
end
