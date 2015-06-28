#!/usr/bin/env ruby

require 'rubygems'
require 'chatterbot/dsl'
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }

include Logging

def process_incoming(handler)
    puts "Processing incoming tweets ..." if bot.debug_mode
    replies do |tweet|
        text = tweet.text
        sender = tweet_user(text)[1..-1]
        handler.handle(sender, 'twitter', text)
    end

    puts "Processing direct messages ..." if bot.debug_mode
    dms = client.direct_messages_received(:since_id => since_id)
    dms.each do |m|
        text = m.text
        sender = m.sender.screen_name
        since_id m.id if since_id.nil? || m.id > since_id
        handler.handle(m.sender.screen_name, 'twitter', text)
    end

    update_config
end

def process_outgoing(handler)
    puts "Processing outgoing messages ..." if bot.debug_mode
    handler.handle
end

db = DB.new
incoming_handler = IncomingHandler.new(db)
outgoing_handler = OutgoingHandler.new(db, client)

logger.debug "Started challenge bot!"

stopped = 0
trap ("SIGINT") { puts "Ctrl+C caught. Stopping gracefully."; stopped += 1 }

begin
    second = 0
    loop do
        process_incoming(incoming_handler) if second % 60 == 0
        process_outgoing(outgoing_handler) if second % 5 == 0
        second = 0 if second >= 60
        break if stopped > 0
        sleep 1
        second += 1
    end
rescue => e
    msg = "Got #{e.class} exception. Retry in 60 seconds.\nException: #{e}\n#{e.backtrace}"
    puts msg
    logger.warning msg
    30.times { sleep 1; exit(0) if stopped > 0 }
    puts "Retry in 30 seconds..."
    30.times { sleep 1; exit(0) if stopped > 0 }
    retry
end
