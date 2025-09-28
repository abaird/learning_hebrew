class RemoveDeckIdFromWords < ActiveRecord::Migration[8.0]
  def change
    remove_reference :words, :deck, null: false, foreign_key: true
  end
end
