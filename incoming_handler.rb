require 'securerandom'
require 'digest/sha1'

class IncomingHandler

    def initialize(db)
        @db = db
    end

    def handle(message, sender)
        puts "FROM #{sender}: handling - #{message}"
        message = strip_names(message).strip
        puts "stripped: '#{message}'"

        case message
        when /send(?: me)?(?: my)?(?: submission)? code/
            registerUser(sender)
        when /submit ([\-_a-zA-Z0-9]+) ([a-zA-Z0-9]+)/
            submitSolution(sender, $1, $2)
        end
    end

    def registerUser(username)
        # TODO: usernames are unique, when adding e-mail users, need to check for that
        code = @db.get_code(username)
        if code.nil?
            code = generate_code
            @db.register_user(username, code)
        end

        @db.queue_dm(username, "your submission code is #{code}")
    end

    def submitSolution(username, challenge, hash)
        challenge = @db.get_challenge(challenge)
        if challenge.nil?
            msg = "invalid challenge: #{challenge}"[0..140]
            @db.queue_dm(username, msg)
            return
        end

        if Date.parse(challenge[:date_begin]) > Date.today
            @db.queue_dm(username, "not started #{challenge}")
            return
        end

        user = @db.get_user_by_username(username)
        if user.nil?
            registerUser(username)
            user = @db.get_user_by_username(username)
        end

        is_correct = check_submission(user[:code], challenge[:solution], hash)
        @db.add_or_update_submission(user[:id], challenge[:id], is_correct, hash)

        if Date.parse(challenge[:date_end]) <= Date.today
            @db.queue_dm(username, "#{challenge} submission is #{is_correct ? 'CORRECT' : 'incorrect'}")
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

#db = DB.new
#h = IncomingHandler.new(db)
#h.handle('submit challenge1 ee2c442da95adbf2541c088f19cb05c9f2734999', 'caleb_fenton')
# echo -n "There is no spoon.16fb58474b8fbdb2ed56c58d326f9334" | openssl sha1
