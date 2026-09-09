class CreatePaymentAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_attempts do |t|
      t.references :booking, null: false, foreign_key: true
      t.integer :status
      t.integer :amount_cents
      t.string :simulated_outcome
      t.string :note

      t.timestamps
    end
  end
end
