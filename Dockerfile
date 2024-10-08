# Use official Ruby image as the base
FROM ruby:3-buster

# Set environment variables
ENV RUBYOPT="-W0"
ENV RUBY_THREAD_VM_STACK_SIZE=5242880
ENV LANG=C.UTF-8

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy Gemfile and Gemfile.lock
COPY Gemfile* ./

# Install Ruby dependencies
RUN bundle install

# Copy the rest of the application code
COPY . .

# Create a directory for logs
RUN mkdir -p /app/logs

# Set buffering to immediate flush
ENV PYTHONUNBUFFERED=1
ENV RUBYOPT="-W0 -E UTF-8:UTF-8"

# Command to run the bot
CMD ["ruby", "bot.rb"]