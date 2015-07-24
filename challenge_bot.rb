#!/usr/bin/env ruby

require 'rubygems'
require 'chatterbot/dsl'
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each { |f| require f }

include Logging

#debug_mode

def process_incoming(handler, bot_name)
    puts 'Processing incoming tweets ...'
    replies do |tweet|
        text = tweet.text
        sender = tweet.user.screen_name
        next if sender.eql?(bot_name)
        client.follow(sender)
        handler.handle(sender, 'twitter', text)
    end

    puts 'Processing direct messages ...'
    dms = client.direct_messages_received(since_id: since_id)
    dms.each do |m|
        text = m.text
        sender = m.sender.screen_name
        since_id m.id if since_id.nil? || m.id > since_id
        next if sender.eql?(bot_name)
        client.follow(sender)
        handler.handle(sender, 'twitter', text)
    end

    update_config
end

def stream_incoming(handler, bot_name)
    puts 'Beginning streaming tweets and direct messages ...'
    streaming do
        replies do |tweet|
            text = tweet.text
            sender = tweet.user.screen_name
            next if sender.eql?(bot_name)
            handler.handle(sender, 'twitter', text)
        end

        direct_message do |m|
            text = m.text
            sender = m.sender.screen_name
            since_id m.id if since_id.nil? || m.id > since_id
            next if sender.eql?(bot_name)
            client.follow(sender)
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
trap('SIGINT') do
    if stopped == 0
        puts 'Ctrl+C caught. Stopping gracefully.'
        stopped += 1
    elsif stopped == 1
        puts 'Press Ctrl+C again to force immediate exit!'
        stopped += 1
    elsif stopped > 1
        exit 0
    end
end

config = db.get_config
logger.debug "Started ChallengeBot - #{config[:bot_name]}!"

begin
    process_incoming(incoming_handler, config[:bot_name])
    threads = []
    threads << Thread.new { stream_incoming(incoming_handler, config[:bot_name]) }
    second = 0
    puts 'Begin processing outgoing message queue ...'
    loop do
        process_dm = second % config[:dm_queue_interval] == 0
        process_outgoing(outgoing_handler) if process_dm

        second += 1
        if second >= (60 * 60)
            logger.debug 'ChallengeBot is alive and well!'
            second = 0
        end

        break if stopped > 0
        sleep 1
    end

    threads.each(&:kill)
rescue => e
    msg = "Exception: #{e.class} - #{e}. Retry in 60 seconds!\n#{e.backtrace.join("\n")}"
    puts msg
    logger.warn msg
    config[:retry_interval].downto(1) do |s|
        sleep 1
        if s % 30 == 0
            msg = "Retry in #{s} seconds ..."
            puts msg
            logger.warn msg
        end

        break if stopped > 0
    end
    retry unless stopped > 0
ensure
    logger.debug 'Updating configuration'
    update_config
end

logger.debug "Gracefully stopped ChallengeBot - #{config[:bot_name]}"
