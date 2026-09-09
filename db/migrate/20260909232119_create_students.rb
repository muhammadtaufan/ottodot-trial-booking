class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.references :parent, null: false, foreign_key: true
      t.string :name

      t.timestamps
    end
  end
end
