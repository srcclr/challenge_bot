require 'securerandom'
require 'digest/sha1'
require 'json'
require_relative 'logging'

class IncomingHandler

    include Logging

    CHALLENGE_NAME = '[\-_a-zA-Z0-9]+'

    def initialize(db)
        @db = db
    end

    def handle(username, user_type, message)
        message = strip_names(message).strip
        puts "Handle #{username} (#{user_type}): #{message}"

        case message
        when /\A(?:send|give|tell)(?: me)?(?: my)?(?: submission)? code\z/i
            register_user(username, user_type)
        when /\Asubmit (#{CHALLENGE_NAME}) ([a-zA-Z0-9]+)\z/i
            submit_answer(username, user_type, $1, $2)
        when /\Acheck (#{CHALLENGE_NAME})\z/i
            check_answer(username, user_type, $1)
        when /\A(?:send|give|tell)(?: me)?(?: a)? secret\z/i
            get_secret(username, user_type)
        when /\Ado you have stairs in your house\??\z/i
            @db.queue_dm(username, user_type, 'i am protected.')
        when /\Ai am protected\.?\z/i
            @db.queue_dm(username, user_type, 'the internet makes you stupid. :D')
        when /\A(?:send|give|tell)(?: me)? (#{CHALLENGE_NAME}) info\z/i
            get_challenge_info(username, user_type, $1)
        when /\Ahelp (#{CHALLENGE_NAME})\z/i
            get_challenge_info(username, user_type, $1)
        when /\Ahelp(?: me)?\z/
            get_help(username, user_type)
        end
    end

private

    def register_user(username, user_type)
        code = @db.get_code(username, user_type)
        if code.nil?
            code = generate_code
            @db.register_user(username, user_type, code)
        end

        @db.queue_dm(username, user_type, "your submission code is #{code}")
    end

    def submit_answer(username, user_type, challenge_name, hash)
        challenge = @db.get_challenge(challenge_name)
        if challenge.nil?
            send_unknown_challenge(username, user_type, challenge_name)
            return
        end

        if challenge[:date_begin] > Date.today
            msg = "#{challenge_name} has not started. begins #{challenge[:date_begin]}"
            @db.queue_dm(username, user_type, msg)
            return
        end

        user = @db.get_user(username, user_type)
        if user.nil?
            register_user(username, user_type)
            user = @db.get_user(username, user_type)
        end

        is_correct = check_submission(user[:code], challenge[:solutions], hash)
        if challenge[:date_end] <= Date.today
            msg = "#{challenge_name} submission is #{is_correct ? 'CORRECT' : 'incorrect'}"
        else
            # Don't allow users to change submissions after challenge is complete.
            # This way score histories are preserved.
            @db.add_or_update_submission(user[:id], challenge[:id], is_correct, hash)
            msg = "#{challenge_name} answer recieved. challenge ends #{challenge[:date_end]}"
        end
        @db.queue_dm(username, user_type, msg)
    end

    def check_answer(username, user_type, challenge_name)
        challenge = @db.get_challenge(challenge_name)
        if challenge.nil?
            send_unknown_challenge(username, user_type, challenge_name)
            return
        end

        if challenge[:date_begin] > Date.today
            msg = "#{challenge_name} has not started. begins #{challenge[:date_begin]}"
            @db.queue_dm(username, user_type, msg)
            return
        end

        if challenge[:date_end] <= Date.today
            sub = @db.get_submission(username, user_type, challenge[:id])
            if sub
                msg = "#{challenge_name} = #{sub[:hash]} and is #{sub[:is_correct] ? 'CORRECT' : 'incorrect'}"
            else
                msg = "you have not submitted an answer for #{challenge_name}"
            end
        else
            msg = "#{challenge_name} is still ongoing. challenge ends #{challenge[:date_end]}"
        end
        @db.queue_dm(username, user_type, msg)
    end

    def get_secret(username, user_type)
        secret = @db.get_secret
        @db.queue_dm(username, user_type, secret) if secret
    end

    def get_challenge_info(username, user_type, challenge_name)
        challenge = @db.get_challenge(challenge_name)
        if challenge.nil?
            send_unknown_challenge(username, user_type, challenge_name)
            return
        end
        info = "#{challenge_name} can be viewed @ #{challenge[:url]}. start=#{challenge[:date_begin]}, end=#{challenge[:date_end]}"
        @db.queue_dm(username, user_type, info)
    end

    def get_help(username, user_type)
        url = @db.get_config[:help_url]
        help = "commands i understand are listed here: #{url}"
        @db.queue_dm(username, user_type, help)
    end

    def send_unknown_challenge(username, user_type, challenge_name)
        # Don't respond with arbitrary, attacker controlled data like challenge_name.
        # After this check, it's known to exist and is safe to emit.
        msg = "unknown challenge :( "[0..140]
        @db.queue_dm(username, user_type, msg)
    end

    def strip_names(message)
        message.gsub(/@[^ ]+ /, '')
    end

    def generate_code
        random_string = SecureRandom.hex
    end

    def check_submission(code, solutions_str, hash)
        solutions = JSON.parse(solutions_str)
        solutions.each do |solution|
            correct = Digest::SHA1.hexdigest("#{solution}#{code}")
            return true if correct.eql?(hash)
        end

        return false
    end

end

#require_relative 'db'
#db = DB.new
#h = IncomingHandler.new(db)
#h.handle('caleb_fenton', 'twitter', 'give me my code')
#h.handle('caleb_fenton', 'twitter', 'send me a secret')
#h.handle('caleb_fenton', 'twitter', 'submit challenge1 864bcc000d5a158b81d63fc5233813bdc0f53a3c')
#h.handle('caleb_fenton', 'twitter', 'submit challenge2 864bcc000d5a158b81d63fc5233813bdc0f53a3c')
#h.handle('caleb_fenton', 'twitter', 'submit challenge3 864bcc000d5a158b81d63fc5233813bdc0f53a3c')
#h.handle('caleb_fenton', 'twitter', 'submit notexist 864bcc000d5a158b81d63fc5233813bdc0f53a3c')
# echo -n "There is no spoon.16fb58474b8fbdb2ed56c58d326f9334" | openssl sha1
