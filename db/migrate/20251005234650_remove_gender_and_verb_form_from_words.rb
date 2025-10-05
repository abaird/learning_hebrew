class RemoveGenderAndVerbFormFromWords < ActiveRecord::Migration[8.0]
  def change
    remove_reference :words, :gender, foreign_key: true
    remove_reference :words, :verb_form, foreign_key: true
  end
end
