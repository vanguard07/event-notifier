require 'telegram/bot'
require 'httparty'
require 'gemini-ai'  # Changed from google/cloud/ai
require 'json'
require 'rufus-scheduler'
require 'time'
require 'tzinfo'
require 'dotenv'
require 'logger'

# Load environment variables from .env file
Dotenv.load

logger = Logger.new(STDOUT)

# Configuration
class Config
  class << self
    def method_missing(method_name)
      env_var = method_name.to_s.upcase
      ENV[env_var] || raise("Missing environment variable: #{env_var}")
    end

    def respond_to_missing?(method_name, include_private = false)
      ENV[method_name.to_s.upcase] || super
    end
  end
end

class TelegramEventBot
  def run
    Telegram::Bot::Client.run(Config.telegram_bot_token) do |bot|
      bot.listen do |message|
        next unless message.is_a?(Telegram::Bot::Types::Message) && message.photo.any?

        chat_id = message.chat.id
        begin
          send_telegram_message(chat_id, 'Processing your image...')

          file_id = message.photo.last.file_id
          extracted_text = process_image(file_id)

          send_telegram_message(chat_id, 'Analyzing the text...')

          analysis = analyze_text(extracted_text)

          if analysis.values.none?(&:nil?)
            schedule_notification(analysis, chat_id)
            response = <<~MESSAGE
              Event detected and notification scheduled:
              Food: #{analysis['food']}
              Date: #{analysis['date']}
              Time: #{analysis['time']}
              Venue: #{analysis['venue']}
              A reminder will be sent 30 minutes before the event.
            MESSAGE
            send_telegram_message(chat_id, response)
          else
            send_telegram_message(chat_id, 'Could not detect a complete event from the image. Please make sure all details are visible.')
          end
        rescue => e
          puts "Error: #{e.message}"
          send_telegram_message(chat_id, 'An error occurred while processing your request.')
        end
      end
    end
  end

  private

  def initialize
    # setup_logger
    @scheduler = Rufus::Scheduler.new

    # Initialize Gemini AI client
    @gemini = Gemini.new(
      credentials: {
        service: 'generative-language-api',
        api_key: Config.google_api_key
      },
      options: { model: Config.google_model_name, server_sent_events: true }
    )
  end

  def process_image(file_id)
    Telegram::Bot::Client.run(Config.telegram_bot_token) do |bot|
      # Fetch the file information
      response = bot.api.get_file(file_id: file_id)

      download_url = "https://api.telegram.org/file/bot#{Config.telegram_bot_token}/#{response.file_path}"
      form_data = {
        detectOrientation: true,
        filetype: 'JPG',
        url: download_url
      }
      
      response = HTTParty.post(
        Config.ocr_base_url,
        body: form_data,
        headers: { 'apikey' => Config.ocr_api_key }
        )
        
        JSON.parse(response.body)['ParsedResults'][0]['ParsedText']
    end
  end

  def analyze_text(text)
    prompt = <<~PROMPT
      Analyze the following text and extract any mention of food, date, time, and venue. 
      Return the result using this JSON Schema:
        { "type": "object",
            "properties": {
                "food": { "type": "string" },
                "date": { "type": "string" },
                "time": { "type": "string" },
                "venue": { "type": "string" },
            }
        }
      date should be in the format YYYY-MM-DD, and time should be in the format HH:MM, 24 hours format. Return only the JSON object, no extra text.
      If no particular food item can be detected, set the value to Available. If any information is missing, set the value to null. 
      Text: #{text}
    PROMPT

    response = @gemini.generate_content( { contents: { role: 'user', parts: { text: prompt } } })
    data = JSON.parse(response.to_json)
    JSON.parse(data['candidates'][0]['content']['parts'][0]['text'])
  rescue JSON::ParserError => e
    puts "Error parsing JSON response: #{e.message}"
    puts "Raw response: #{response}"
    raise "Failed to parse event details from the image"
  end

  def schedule_notification(event, chat_id)
    food, date, time, venue = event.values_at('food', 'date', 'time', 'venue')
    
    tz = TZInfo::Timezone.get('America/Chicago')
    event_time = Time.parse("#{date} #{time}")
    notification_time = event_time - (30 * 60)  # 30 minutes before

    @scheduler.at notification_time do
      if Time.now.to_date == event_time.to_date
        timezone_name = tz.now.strftime('%Z')
        send_telegram_message(chat_id, "Reminder: Event for #{food} at #{venue} is starting soon! (#{timezone_name})")
      end
    end
  end

  def send_telegram_message(chat_id, text)
    Telegram::Bot::Client.run(Config.telegram_bot_token) do |bot|
      bot.api.send_message(chat_id: chat_id, text: text)
    end
  end
end

# Start the bot
puts 'Bot is running...'
logger.info 'Bot is running...'
bot = TelegramEventBot.new
bot.run