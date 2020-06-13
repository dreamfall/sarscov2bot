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

  WORLDOMETER_URL = "https://www.worldometers.info/coronavirus/"

  TOTAL_POPULATION = 7770000000

  def perform
    Dotenv.load

    doc = Nokogiri::HTML(URI.open(WORLDOMETER_URL))

    attributes = {
      total_cases_number: cell_to_number(doc.css("#maincounter-wrap")[0].css(".maincounter-number span")),
      deaths_number: cell_to_number(doc.css("#maincounter-wrap")[1].css(".maincounter-number span")),
      recovered_number: cell_to_number(doc.css("#maincounter-wrap")[1].css(".maincounter-number span"))
    }

    puts attributes

    last_entry = StatisticalEntry.order(:created_at).last
    new_entry = StatisticalEntry.new(attributes)

    if (!last_entry || new_entry.differs_to?(last_entry)) && new_entry.save
      update_channel_topic!(new_entry)

      # post_update_by_country!(tbody)
    else
      puts "Stats unchanged. Skipping..."
    end
  end

  private

  def post_update_by_country!(tbody)
    updates = []

    # Skipping empty rows and headers
    tbody.css("tr")[7..-1].each do |row|
      cells = row.css("td")
      name = cells[0].text.delete("*")

      break if name == "TOTAL"

      attributes = {
        total_cases_number: cell_to_number(cells[1]),
        daily_cases_number: cell_to_number(cells[2]),
        deaths_number: cell_to_number(cells[3]),
        daily_deaths_number: cell_to_number(cells[4]),
        recovered_number: cell_to_number(cells[7])
      }

      entry = CountryStatisticalEntry.find_or_initialize_by(country: name)

      if entry.is_going_to_be_changed?(attributes)
        if entry.new_record?
          updates << "#{name} 🆕:\n#{formatted_changes_by_country(attributes, entry)}"
        elsif entry.followed?
          updates << "#{name}:\n#{formatted_changes_by_country(attributes, entry)}"
        end

        [:daily_cases_number, :daily_deaths_number].each { |k| attributes.delete(k) }

        entry.attributes = attributes
        entry.save
      end
    end

    send_message(updates.join("\n\n")) if updates.any?
  end

  def send_message(message)
    return unless message.present?

    Telegram::Bot::Client.run(ENV["TELEGRAM_TOKEN"]) do |bot|
      bot.api.sendMessage(chat_id: chat_id, text: message)
    end
  end

  def chat_id
    ENV["STAGING"] == "true" ? ENV["STAGING_CHAT_ID"] : ENV["CHAT_ID"]
  end

  def formatted_changes_by_country(attrs, entry)
    changes = []

    if attrs[:total_cases_number] != entry.total_cases_number
      changes << "Total #{formatted_growth(attrs[:total_cases_number],  entry.total_cases_number)}"
      cases_diff = attrs[:total_cases_number] - entry.total_cases_number
      changes << "Today: #{attrs[:daily_cases_number]}" if attrs[:daily_cases_number] > 0 && attrs[:daily_cases_number] != cases_diff
    end

    if attrs[:deaths_number] != entry.deaths_number
      changes << "Deaths #{formatted_growth(attrs[:deaths_number], entry.deaths_number)}"
      deaths_diff = attrs[:deaths_number] - entry.deaths_number
      changes << "Today: #{attrs[:daily_deaths_number]}" if attrs[:daily_deaths_number] > 0 && attrs[:daily_deaths_number] != deaths_diff
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
    infected = (entry.total_cases_number.to_f / TOTAL_POPULATION * 100).round(4)

    title = "CoronaV [🦠#{short_number_with_delimiter(entry.total_cases_number)} / 💚 #{short_number_with_delimiter(entry.recovered_number)} / 💀#{number_with_delimiter(entry.deaths_number)} / 🌍 #{infected}%]"

    Telegram::Bot::Client.run(ENV["TELEGRAM_TOKEN"]) do |bot|
      bot.api.setChatTitle(chat_id: chat_id, title: title)
    end
  end

  def short_number_with_delimiter(number)
    number_with_delimiter(number).split(" ")[0..-2].join(" ") + "k"
  end

  def number_with_delimiter(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse
  end

  def cell_to_number(cell)
    cell.text.delete(",").to_i
  end
end
