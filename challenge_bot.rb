#!/usr/bin/env ruby

require 'rubygems'
require 'chatterbot/dsl'
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each { |f| require f }

include Logging

#debug_mode
HEARTBEAT_INTERVAL = 60 * 60 # Every hour
STATE_RUNNING = 0
STATE_STOPPING = 1
STATE_HALTING = 2

def process_incoming(handler, bot_name)
    puts '[*] Processing tweets'
    replies do |tweet|
        sender = tweet.user.screen_name
        next if sender.eql?(bot_name)
        text = tweet.text
        created_at = tweet.created_at.dup.localtime
        handler.handle(sender, 'twitter', text, created_at)
    end
    puts '[*] Finished processing tweets'

    puts '[*] Processing direct messages'
    dms = client.direct_messages_received(since_id: since_id)
    dms.each do |dm|
        sender = dm.sender.screen_name
        since_id(dm.id) if since_id.nil? || dm.id > since_id
        next if sender.eql?(bot_name)
        text = dm.text
        created_at = dm.created_at.dup.localtime
        handler.handle(sender, 'twitter', text, created_at)
    end
    puts '[*] Finished processing direct messages'

    update_config
end

def stream_incoming(handler, bot_name)
    puts '[*] Streaming tweets and direct messages'
    streaming do
        replies do |tweet|
            sender = tweet.user.screen_name
            next if sender.eql?(bot_name)
            text = tweet.text
            created_at = tweet.created_at.dup.localtime
            handler.handle(sender, 'twitter', text)
        end

        direct_message do |dm|
            sender = dm.sender.screen_name
            since_id(dm.id) if since_id.nil? || dm.id > since_id
            next if sender.eql?(bot_name)
            text = dm.text
            created_at = dm.created_at.dup.localtime
            handler.handle(sender, 'twitter', text, created_at)
        end
    end
end

def process_outgoing(handler, dm_queue_interval)
    puts '[*] Watching outgoing message queue'
    second = 0
    loop do
        second += 1
        process_dm = second % dm_queue_interval == 0
        if process_dm
            handler.handle
            second = 0
        end

        sleep 1
    end
end


db = DB.new
incoming_handler = IncomingHandler.new(db)
outgoing_handler = OutgoingHandler.new(db, client)

state = 0
trap('SIGINT') do
    if state == STATE_RUNNING
        puts '[!] Ctrl+C caught. Stopping gracefully.'
        state = STATE_STOPPING
    elsif state == STATE_STOPPING
        puts '[!!] Press Ctrl+C again to force immediate exit!'
        state = STATE_HALTING
    elsif state >= STATE_HALTING
        exit 0
    end
end

config = db.get_config
logger.debug "[*] Started ChallengeBot - #{config[:bot_name]}!"

begin
    # Deal with anything sent to us while turned off
    process_incoming(incoming_handler, config[:bot_name])

    threads = []
    threads << Thread.new { stream_incoming(incoming_handler, config[:bot_name]) }
    threads << Thread.new { process_outgoing(outgoing_handler, config[:dm_queue_interval]) }

    second = 0
    loop do
        second += 1
        if second >= HEARTBEAT_INTERVAL
            logger.debug '[.] ChallengeBot is alive and well!'
            second = 0

            # bit of a hack, but need to make sure config gets updated
            # since it keeps track of messages we've seen and responded to
            # if there's a failure, it could mean sending messages repeatedly
            update_config
        end

        break if state > STATE_RUNNING
        sleep 1
    end

    threads.each(&:kill)
rescue => e
    msg = "[!] Exception: #{e.class} - #{e}. Retry in #{config[:retry_interval]} seconds!\n#{e.backtrace.join("\n")}"
    puts msg
    logger.warn msg
    config[:retry_interval].downto(1) do |s|
        sleep 1
        if s % 30 == 0
            msg = "[.] Retry in #{s} seconds"
            puts msg
            logger.warn msg
        end

        break if state != STATE_RUNNING
    end

    if state == STATE_RUNNING
        threads.each(&:kill)
        update_config
        retry
    end
ensure
    logger.debug 'Saving configuration'
    update_config
end

logger.debug "Gracefully state ChallengeBot - #{config[:bot_name]}"
