class CreateGenders < ActiveRecord::Migration[8.0]
  def change
    create_table :genders do |t|
      t.string :name, null: false
      t.string :abbrev, null: false

      t.timestamps
    end

    add_index :genders, :name, unique: true
    add_index :genders, :abbrev, unique: true
  end
end
