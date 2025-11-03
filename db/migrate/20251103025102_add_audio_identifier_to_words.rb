class AddAudioIdentifierToWords < ActiveRecord::Migration[8.0]
  def change
    add_column :words, :audio_identifier, :string
    # Index is not unique because multiple words can share the same audio
    # (e.g., words differing only in cantillation marks)
    add_index :words, :audio_identifier

    # Backfill existing words with audio identifiers
    reversible do |dir|
      dir.up do
        Word.find_each do |word|
          # Generate identifier without triggering validations
          identifier = Word.hash_hebrew_text(word.representation)
          word.update_column(:audio_identifier, identifier)
        end
      end
    end
  end
end
