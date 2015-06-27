require 'securerandom'
require 'digest/sha1'
require './logging.rb'

class IncomingHandler

    include Logging

    def initialize(db)
        @db = db
    end

    def handle(username, user_type, message)
        message = strip_names(message).strip
        puts "Handling #{username} (#{user_type}): #{message}"

        case message
        when /(?:send|give)(?: me)?(?: my)?(?: submission)? code/
            registerUser(username, user_type)
        when /submit ([\-_a-zA-Z0-9]+) ([a-zA-Z0-9]+)/
            submitSolution(username, user_type, $1, $2,)
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

    def submitSolution(username, user_type, challenge, hash)
        challenge = @db.get_challenge(challenge)
        if challenge.nil?
            msg = "invalid challenge: #{challenge}"[0..140]
            @db.queue_dm(username, user_type, msg)
            return
        end

        if Date.parse(challenge[:date_begin]) > Date.today
            @db.queue_dm(username, user_type, "not started #{challenge}")
            return
        end

        user = @db.get_user(username, user_type)
        if user.nil?
            registerUser(username, user_type)
            user = @db.get_user(username, user_type)
        end

        is_correct = check_submission(user[:code], challenge[:solution], hash)
        @db.add_or_update_submission(user[:id], challenge[:id], is_correct, hash)

        if Date.parse(challenge[:date_end]) <= Date.today
            @db.queue_dm(username, user_type, "#{challenge} submission is #{is_correct ? 'CORRECT' : 'incorrect'}")
        end
    end

private

    def strip_names(message)
        message.gsub(/@[^ ]+ /, '')
    end

    def generate_code
        random_string = SecureRandom.hex
    end

    def check_submission(code, solution, hash)
        puts "digesting: '#{solution}#{code}'"
        correct = Digest::SHA1.hexdigest("#{solution}#{code}")
        puts "correct = #{correct}"
        puts "hash    = #{hash}"

        correct.eql?(hash)
    end

end

#require './db'
#db = DB.new
#h = IncomingHandler.new(db)
#h.handle('caleb_fenton', 'twitter', 'give me my code')

#h.handle('caleb_fenton', 'twitter', 'submit challenge1 ee2c442da95adbf2541c088f19cb05c9f2734999')
# echo -n "There is no spoon.16fb58474b8fbdb2ed56c58d326f9334" | openssl sha1
