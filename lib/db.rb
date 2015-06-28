require 'sequel'
require 'mysql'
require 'yaml'
require_relative 'logging'

class DB

    include Logging

    def initialize
        config = YAML::load_file(File.join(__dir__, '../challenge_bot.yml'))
        @conn = Sequel.connect(config[:db_uri])
        Dir[File.dirname(__FILE__) + '/../models/*.rb'].each { |f| require f }
    end

    def get_user_type_id(user_type)
        @conn[:user_types][:name => user_type][:id]
    end

    def get_user(username, user_type)
        user_type_id = get_user_type_id(user_type)
        @conn[:users][:username => username, :user_type_id => user_type_id]
    end

    def get_challenge(name)
        @conn[:challenges][:name => name]
    end

    def get_code(username, user_type)
        user = get_user(username, user_type)
        return nil if user.nil?

        user[:code]
    end

    def register_user(username, user_type, code)
        users = @conn[:users]
        user_type_id = get_user_type_id(user_type)
        users.insert(:username => username, :user_type_id => user_type_id, :code => code)
    end

    def queue_dm(username, user_type, message)
        logger.debug "Queueing #{username} (#{user_type}) - #{message}"
        DirectMessage.insert(:username => username, :user_type => user_type, :message => message)
    end

    def peek_dm
        DirectMessage.first
    end

    def get_secret
        @conn[:secrets].order{ rand{} }.first[:secret]
    end

    def add_or_update_submission(user_id, challenge_id, is_correct, hash)
        sub = Submission[:user_id => user_id, :challenge_id => challenge_id]
        if sub.nil?
            Submission.insert(:user_id => user_id, :challenge_id => challenge_id, :hash => hash, :is_correct => is_correct)
        else
            # Use model#update to fire trigger, model#save doesn't work
            submission_count = sub[:submission_count] += 1
            sub.update(:submission_count => submission_count, :is_correct => is_correct, :hash => hash)
        end
    end

end

#db = DB.new
#puts db.get_secret
#puts db.peek_dm
