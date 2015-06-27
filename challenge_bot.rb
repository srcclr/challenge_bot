#!/usr/bin/env ruby

require 'rubygems'
require 'chatterbot/dsl'
require 'securerandom'

# remove this to send out tweets
debug_mode

# remove this to update the db
#no_update

# remove this to get less output when running
verbose

# Load configuration
# refresh interval

def do_loop
    loop do
        puts "Processing incoming tweets ..."
        replies do |tweet|
          text = tweet.text
          sender = tweet_user(text)[1..-1]
          puts "tweet received: #{sender} - #{text}"
          handle(text, sender)
        end

        puts "Processing direct messages ..."
        dms = client.direct_messages_received(:since_id => since_id)
        dms.each do |m|
            text = m.text
            sender = m.sender.screen_name
            since_id m.id if since_id.nil? || m.id > since_id
            puts "dm received: #{sender} - #{text}"
            handle(text, m.sender.screen_name)
        end

        update_config

        break
        sleep 15
    end
end

def handle(message, sender)
    puts "FROM #{sender}: handling - #{message}"
    message = strip_names(message).strip
    puts "stripped: '#{message}'"

    case message
    when /send(?: me)?(?: my)?(?: submission)? code/
        handleGenerateCode(sender)
    when /submit ([^ ]+) ([a-zA-Z0-9])+/
        handleSubmitAnswer(sender, $1, $2)
    end
end

def handleGenerateCode(username)
    # Check if code exists for username
    # If it exists, return it
    # Else, generate_code and save it
    puts "HANDLE GENERATE CODE #{username}"
end

def handleSubmitAnswer(username, challenge, answer_hash)
    puts "HANDLE SUBMIT ANSWER #{username}, #{challenge}, #{answer_hash}"
end

def strip_names(message)
    message.gsub(/@[^ ]+ /, '')
end

def generate_code
    random_string = SecureRandom.hex
end


begin
    do_loop
rescue => e
    puts "Got exception. Waiting 60 seconds and retrying. Exception:\n#{e}"
    sleep 60
    retry
end
