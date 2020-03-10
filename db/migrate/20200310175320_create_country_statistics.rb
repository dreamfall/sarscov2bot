class CreateCountryStatistics < ActiveRecord::Migration[6.0]
  def change
    create_table :country_statistical_entries do |t|
      t.string :country, null: false
      t.integer :total_cases_number, null: false, default: 0
      t.integer :deaths_number, null: false, default: 0
      t.integer :recovered_number, null: false, default: 0

      t.datetime :created_at, null: false
    end
  end
end
