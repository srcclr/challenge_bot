require 'sequel'
require 'mysql'
require 'yaml'

class DB

    def initialize
        config = YAML::load_file(File.join(__dir__, 'challenge_bot.yml'))
        @conn = Sequel.connect(config[:db_uri])
        require './models/submission'
        require './models/direct_message'
    end

    def get_user_by_username(username)
        @conn[:users][:username => username]
    end

    def get_challenge(name)
        @conn[:challenges][:name => name]
    end

    def get_code(username)
        user = get_user_by_username(username)
        return nil if user.nil?

        user[:code]
    end

    def register_user(username, code)
        users = @conn[:users]
        users.insert(:username => username, :code => code)
    end

    def queue_dm(username, message)
        DirectMessage.insert(:username => username, :message => message)
    end

    def pop_dm
        dm = DirectMessage.first
        return nil if dm.nil?

        dm.destroy
        dm
    end

    def add_or_update_submission(user_id, challenge_id, is_correct, hash)
        sub = Submission[:user_id => user_id, :challenge_id => challenge_id]
        if sub.nil?
            Submission.insert(:user_id => user_id, :challenge_id => challenge_id, :hash => hash, :is_correct => is_correct)
        else
            # Use update rather than updating + save to trigger on update mysql
            submission_count = sub[:submission_count] += 1
            sub.update(:submission_count => submission_count, :is_correct => is_correct, :hash => hash)
        end
    end

end

#db = DB.new
#puts db.pop_dm
