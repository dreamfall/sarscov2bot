require "sidekiq"
require "nokogiri"
require "open-uri"
require "./models/statistical_entry"

class UpdateWorker
  include Sidekiq::Worker

  SPREADSHEET_URL = "https://docs.google.com/spreadsheets/u/0/d/e/2PACX-1vR30F8lYP3jG7YOq8es0PBpJIE5yvRVZffOyaqC0GgMBN6yt0Q-NI8pxS7hd1F9dYXnowSC6zpZmW9D/pubhtml/sheet?headers=false&gid=0"

  def perform
    doc = Nokogiri::HTML(URI.open(SPREADSHEET_URL))

    tbody = doc.css("tbody")

    numbers_row = tbody.css("tr")[3]
    number_cells = numbers_row.css("td")

    total_cases_number = cell_to_number(number_cells[0])
    deaths_number = cell_to_number(number_cells[1])
    recovered_number = cell_to_number(number_cells[2])

    puts "Cases: #{total_cases_number}. Deaths: #{deaths_number}. Recovered: #{recovered_number}"

    last_entry = StatisticalEntry.order(:created_at).last
    new_entry = StatisticalEntry.new

    if !last_entry || last_entry.total_cases_number != total_cases_number
      new_entry.total_cases_number = total_cases_number
    end

    if !last_entry || last_entry.deaths_number != deaths_number
      new_entry.deaths_number = deaths_number
    end

    if !last_entry || last_entry.recovered_number != recovered_number
      new_entry.recovered_number = recovered_number
    end

    if new_entry.save
      puts new_entry.to_yaml
    else
      puts "Stats unchanged. Skipping..."
    end
  end

  private

  def cell_to_number(cell)
    cell.text.delete(",").to_i
  end
end
