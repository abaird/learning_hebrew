class CreateVerbForms < ActiveRecord::Migration[8.0]
  def change
    create_table :verb_forms do |t|
      t.string :name, null: false
      t.string :abbrev, null: false

      t.timestamps
    end

    add_index :verb_forms, :name, unique: true
    add_index :verb_forms, :abbrev, unique: true
  end
end
