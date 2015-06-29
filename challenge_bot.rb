#!/usr/bin/env ruby

require 'rubygems'
require 'chatterbot/dsl'
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each { |f| require f }

include Logging

#debug_mode

$my_name = 'cherlerngebert1'

def process_incoming(handler)
    puts "Processing incoming tweets ..."
    replies do |tweet|
        text = tweet.text
        sender = tweet.user.screen_name
        handler.handle(sender, 'twitter', text)
    end

    puts "Processing direct messages ..."
    dms = client.direct_messages_received(:since_id => since_id)
    dms.each do |m|
        text = m.text
        sender = m.sender.screen_name
        since_id m.id if since_id.nil? || m.id > since_id
        next if sender.eql?($my_name)
        handler.handle(sender, 'twitter', text)
    end

    update_config
end

def stream_incoming(handler)
    puts "Beginning streaming tweets and direct messages ..."
    streaming do
        replies do |tweet|
            text = tweet.text
            sender = tweet.user.screen_name
            handler.handle(sender, 'twitter', text)
        end

        direct_message do |m|
            text = m.text
            sender = m.sender.screen_name
            since_id m.id if since_id.nil? || m.id > since_id
            next if sender.eql?($my_name)
            handler.handle(sender, 'twitter', text)
        end
    end
end

def process_outgoing(handler)
    #puts "Processing outgoing messages ..."
    handler.handle
end

db = DB.new
incoming_handler = IncomingHandler.new(db)
outgoing_handler = OutgoingHandler.new(db, client)

stopped = 0
trap ("SIGINT") do
    if stopped == 0
        puts "Ctrl+C caught. Stopping gracefully."
        stopped += 1
    elsif stopped == 1
        puts "Press Ctrl+C again to force immediate exit!"
        stopped += 1
    elsif stopped > 1
        exit 0
    end
end

logger.debug "Started challenge bot!"

begin
    raise 'test error'
    #process_incoming(incoming_handler)
    threads = []
    #threads << Thread.new { stream_incoming(incoming_handler) }
    second = 0
    puts "Begin processing outgoing message queue ..."
    loop do
        #process_outgoing(outgoing_handler) if second % 5 == 0
        second = 0 if second >= 60
        break if stopped > 0
        sleep 1
        second += 1
    end

    threads.each(&:kill)
rescue => e
    msg = "Got #{e.class} exception. Retry in 60 seconds.\nException: #{e}\n#{e.backtrace.join("\n")}"
    puts msg
    logger.warn msg
    60.downto(1) do |s|
        sleep 1
        puts "Retry in 30 seconds" if s == 30
        break if stopped > 0
    end
    retry unless stopped > 0
ensure
    update_config
end

logger.debug "Gracefully stopped challenge bot"
