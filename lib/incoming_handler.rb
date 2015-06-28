require 'securerandom'
require 'digest/sha1'
require_relative 'logging'

class IncomingHandler

    include Logging

    def initialize(db)
        @db = db
    end

    def handle(username, user_type, message)
        message = strip_names(message).strip
        puts "Handling #{username} (#{user_type}): #{message}"

        case message
        when /(?:send|give|tell)(?: me)?(?: my)?(?: submission)? code/
            registerUser(username, user_type)
        when /submit ([\-_a-zA-Z0-9]+) ([a-zA-Z0-9]+)/
            submitSolution(username, user_type, $1, $2,)
        when /(?:send|give|tell)(?: me)?(?: a)? secret/
            sendSecret(username, user_type)
        end
    end

    def registerUser(username, user_type)
        code = @db.get_code(username, user_type)
        if code.nil?
            code = generate_code
            @db.register_user(username, user_type, code)
        end

        @db.queue_dm(username, user_type, "your submission code is #{code}")
    end

    def submitSolution(username, user_type, challenge_name, hash)
        challenge = @db.get_challenge(challenge_name)
        if challenge.nil?
            msg = "invalid challenge: #{challenge_name}"[0..140]
            @db.queue_dm(username, user_type, msg)
            return
        end

        if challenge[:date_begin] > Date.today
            @db.queue_dm(username, user_type, "not started #{challenge_name}")
            return
        end

        user = @db.get_user(username, user_type)
        if user.nil?
            registerUser(username, user_type)
            user = @db.get_user(username, user_type)
        end

        is_correct = check_submission(user[:code], challenge[:solution], hash)
        @db.add_or_update_submission(user[:id], challenge[:id], is_correct, hash)

        if challenge[:date_end] <= Date.today
            @db.queue_dm(username, user_type, "#{challenge_name} submission is #{is_correct ? 'CORRECT' : 'incorrect'}")
        end
    end

    def sendSecret(username, user_type)
        secret = @db.get_secret
        @db.queue_dm(username, user_type, secret) if secret
    end

private

    def strip_names(message)
        message.gsub(/@[^ ]+ /, '')
    end

    def generate_code
        random_string = SecureRandom.hex
    end

    def check_submission(code, solution, hash)
        correct = Digest::SHA1.hexdigest("#{solution}#{code}")
        correct.eql?(hash)
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
