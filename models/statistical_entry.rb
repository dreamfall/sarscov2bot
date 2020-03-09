class StatisticalEntry < ActiveRecord::Base
  validates :total_cases_number, :deaths_number, :recovered_number, presence: true
end
