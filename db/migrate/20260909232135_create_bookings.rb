class CreateBookings < ActiveRecord::Migration[8.1]
  def change
    create_table :bookings do |t|
      t.references :student, null: false, foreign_key: true
      t.references :trial_class, null: false, foreign_key: true
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :bookings, [:student_id, :trial_class_id], unique: true, where: "status = 1"
  end
end
