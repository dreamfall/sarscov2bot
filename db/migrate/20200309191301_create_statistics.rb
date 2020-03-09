class CreateStatistics < ActiveRecord::Migration[6.0]
  def change
    create_table :statistical_entries do |t|
      t.integer :total_cases_number, null: false
      t.integer :deaths_number, null: false
      t.integer :recovered_number, null: false

      t.datetime :created_at, null: false
    end
  end
end
