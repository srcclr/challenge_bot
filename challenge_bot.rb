#!/usr/bin/env ruby

require 'rubygems'
require 'chatterbot/dsl'

class ChallengeBot

    def initialize
        # remove this to send out tweets
        debug_mode

        # remove this to update the db
        #no_update

        # remove this to get less output when running
        verbose

        # Load configuration
        # refresh interval
    end

    def start
        #since_id = 0
        begin
            do_loop
        rescue => e
            puts "Got exception. Waiting 60 seconds and retrying. Exception:\n#{e}"
            sleep 60
            retry
        end
    end

    def stop
    end

private

    def do_loop
        loop do
            puts "Processing incoming tweets ..."
            replies do |tweet|
              text = tweet.text
              puts "tweet received: #{text}"
              handle(text)
            end

            puts "Processing direct messages ..."
            dms = client.direct_messages_received(:since_id => since_id)
            dms.each do |m|
                text = m.text
                since_id m.id if since_id.nil? || m.id > since_id
                puts "dm received: #{text}"
                handle(text)
            end

            update_config

            break
            sleep 15
        end
    end

    def handle(message)
        puts "handling message - #{message}"

    end

    def handleGenerateCode(username)
    end

    def handleSubmitAnswer(username, challenge, answer_hash)
    end

end
