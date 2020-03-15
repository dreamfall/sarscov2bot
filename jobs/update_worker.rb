# coding: utf-8
require "sidekiq"
require "nokogiri"
require "open-uri"
require "./models/statistical_entry"
require "./models/country_statistical_entry"
require "telegram/bot"
require "dotenv"

class UpdateWorker
  include Sidekiq::Worker

  SPREADSHEET_URL = "https://docs.google.com/spreadsheets/u/0/d/e/2PACX-1vR30F8lYP3jG7YOq8es0PBpJIE5yvRVZffOyaqC0GgMBN6yt0Q-NI8pxS7hd1F9dYXnowSC6zpZmW9D/pubhtml/sheet?headers=false&gid=0"

  def perform
    Dotenv.load

    doc = Nokogiri::HTML(URI.open(SPREADSHEET_URL))

    tbody = doc.css("tbody")

    numbers_row = tbody.css("tr")[3]
    number_cells = numbers_row.css("td")

    attributes = {
      total_cases_number: cell_to_number(number_cells[0]),
      deaths_number: cell_to_number(number_cells[1]),
      recovered_number: cell_to_number(number_cells[2])
    }

    puts attributes

    last_entry = StatisticalEntry.order(:created_at).last
    new_entry = StatisticalEntry.new(attributes)

    if (!last_entry || new_entry.differs_to?(last_entry)) && new_entry.save
      update_channel_topic!(new_entry)

      post_update_by_country!(tbody)
    else
      puts "Stats unchanged. Skipping..."
    end
  end

  private

  def post_update_by_country!(tbody)
    updates = []

    # Skipping empty rows and headers
    tbody.css("tr")[6..-1].each do |row|
      cells = row.css("td")
      name = cells[0].text.delete("*")

      break if name == "TOTAL"

      attributes = {
        total_cases_number: cell_to_number(cells[1]),
        deaths_number: cell_to_number(cells[2]),
        recovered_number: cell_to_number(cells[5])
      }

      entry = CountryStatisticalEntry.find_or_initialize_by(country: name)

      if entry.is_going_to_be_changed?(attributes)
        if entry.new_record?
          updates << "#{name} 🆕:\n#{formatted_changes_by_country(attributes, entry)}"
        else
          updates << "#{name}:\n#{formatted_changes_by_country(attributes, entry)}"
        end

        entry.attributes = attributes
        entry.save
      end
    end

    send_message(updates.join("\n\n"))
  end

  def send_message(message)
    return unless message.present?

    Telegram::Bot::Client.run(ENV["TELEGRAM_TOKEN"]) do |bot|
      bot.api.sendMessage(chat_id: ENV["CHAT_ID"], text: message)
    end
  end

  def formatted_changes_by_country(attrs, entry)
    changes = []

    if attrs[:total_cases_number] != entry.total_cases_number
      changes << "Total #{formatted_growth(attrs[:total_cases_number],  entry.total_cases_number)}"
    end

    if attrs[:deaths_number] != entry.deaths_number
      changes << "Deaths #{formatted_growth(attrs[:deaths_number], entry.deaths_number)}"
    end

    if attrs[:recovered_number] != entry.recovered_number
      changes << "Recovered #{formatted_growth(attrs[:recovered_number], entry.recovered_number)}"
    end

    changes.join("\n")
  end

  def formatted_growth(new_number, old_number)
    diff = new_number - old_number

    if diff < 0
      "⬇ #{diff}"
    elsif diff > 0
      "⬆ #{diff}"
    end
  end

  def update_channel_topic!(entry)
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
