class AddIsDictionaryEntryToWords < ActiveRecord::Migration[8.0]
  def change
    add_column :words, :is_dictionary_entry, :boolean, default: true, null: false
    add_index :words, :is_dictionary_entry

    # Backfill existing records
    reversible do |dir|
      dir.up do
        # Set is_dictionary_entry for all existing words
        Word.find_each do |word|
          word.update_column(:is_dictionary_entry, word.is_dictionary_entry?)
        end
      end
    end
  end
end
