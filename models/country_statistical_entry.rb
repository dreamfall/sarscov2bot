require "sinatra/activerecord"

class CountryStatisticalEntry < ActiveRecord::Base
  validates :total_cases_number, presence: true, numericality: { greater_than: 0 }
  validates :deaths_number, :recovered_number, numericality: true
  validates :country, presence: true

  def is_going_to_be_changed?(attrs)
    attrs[:total_cases_number] != total_cases_number ||
      attrs[:deaths_number] != deaths_number ||
      attrs[:recovered_number] != recovered_number
  end
end
