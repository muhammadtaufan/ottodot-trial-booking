class CreateTrialClasses < ActiveRecord::Migration[8.1]
  def change
    create_table :trial_classes do |t|
      t.string :subject
      t.datetime :starts_at
      t.integer :capacity, default: 4, null: false

      t.timestamps
    end
  end
end
