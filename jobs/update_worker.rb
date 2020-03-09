# coding: utf-8
require "sidekiq"
require "nokogiri"
require "open-uri"
require "./models/statistical_entry"
require "telegram/bot"
require "dotenv"

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
      update_channel_topic(new_entry).to_yaml
    else
      puts "Stats unchanged. Skipping..."
    end
  end

  private

  def update_channel_topic(entry)
    Dotenv.load

    cfr = (entry.deaths_number.to_f / entry.total_cases_number * 100).round(2)

    title = "CoronaV [🦠#{number_with_delimiter(entry.total_cases_number)} / 💚 #{number_with_delimiter(entry.recovered_number)} / 💀#{number_with_delimiter(entry.deaths_number)} / CFR #{cfr}%]"

    Telegram::Bot::Client.run(ENV["TELEGRAM_TOKEN"]) do |bot|
      bot.api.setChatTitle(chat_id: ENV["CHAT_ID"], title: title)
    end
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse
  end

  def cell_to_number(cell)
    cell.text.delete(",").to_i
  end
end
