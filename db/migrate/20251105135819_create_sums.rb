class CreateSums < ActiveRecord::Migration[8.1]
  def change
    create_table :sums do |t|
      t.integer :value, null: false

      t.timestamps
    end
  end
end
