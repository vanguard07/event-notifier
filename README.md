# Telegram Event Bot

A Telegram bot that extracts event details from images using OCR and Gemini AI, then schedules reminders for the events.

## Features

- 📷 Processes images to extract text using OCR
- 🤖 Analyzes text using Gemini AI to identify event details
- 📅 Automatically schedules event reminders
- ⏰ Sends notifications 30 minutes before events

## Prerequisites

- Docker
- Telegram Bot Token
- Gemini AI API Key
- OCR API Key (from OCR.space or similar service)

## Setup

1. Clone the repository
```bash
git clone [your-repository-url]
cd telegram-event-bot
```

2. Create a `.env` file in the project root:
```
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
GOOGLE_API_KEY=your_gemini_ai_api_key
OCR_API_KEY=your_ocr_api_key
OCR_BASE_URL=https://api.ocr.space/parse/image
GOOGLE_MODEL_NAME=gemini-pro
```

3. Build and run with Docker:
```bash
docker build -t telegram-event-bot .
docker run -d --env-file .env telegram-event-bot

OR

docker-compose up --build
```

## Usage

1. Start a chat with your bot on Telegram
2. Send an image containing event details (food, date, time, venue)
3. The bot will extract the information and schedule a reminder
4. You'll receive a confirmation message with the extracted details
5. 30 minutes before the event, you'll receive a reminder

## License

This project is licensed under the MIT License - see the LICENSE file for details.