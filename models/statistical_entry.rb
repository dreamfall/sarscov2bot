require "sinatra/activerecord"

class StatisticalEntry < ActiveRecord::Base
  validates :total_cases_number, :deaths_number, :recovered_number, presence: true, numericality: { greater_than: 0 }

  def differs_to?(entry)
    entry.recovered_number != recovered_number ||
      entry.deaths_number != deaths_number ||
      entry.total_cases_number != total_cases_number
  end
end
