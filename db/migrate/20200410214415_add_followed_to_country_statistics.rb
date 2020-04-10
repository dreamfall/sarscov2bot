class AddFollowedToCountryStatistics < ActiveRecord::Migration[6.0]
  def change
    add_column :country_statistical_entries, :followed, :boolean, default: false
  end
end
