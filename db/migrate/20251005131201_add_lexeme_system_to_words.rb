class AddLexemeSystemToWords < ActiveRecord::Migration[8.0]
  def change
    # Self-referential relationship - forms point to their lexeme
    add_reference :words, :lexeme, foreign_key: { to_table: :words }, null: true, index: true

    # Flexible metadata (PostgreSQL JSONB)
    # Stores ALL grammatical information (number, gender, status, aspect, conjugation, etc.)
    # Also stores import fields: pos_type, lesson_introduced, function
    add_column :words, :form_metadata, :jsonb, default: {}, null: false
    add_index :words, :form_metadata, using: :gin
  end
end
