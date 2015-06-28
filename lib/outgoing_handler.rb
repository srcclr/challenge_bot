require_relative 'logging'

class OutgoingHandler

    include Logging

    def initialize(db, client)
        @db = db
        @client = client
    end

    def handle
        dm = @db.peek_dm
        return if dm.nil?

        case dm[:user_type]
        when 'twitter'
            send_dm(dm[:username], dm[:message])
        when 'email'
            send_email(dm[:username], dm[:message])
        end

        dm.destroy
    end

    def send_dm(username, message)
        puts "Sending DM to #{username}: #{message}"
        begin
            client.create_direct_message(username, message)
        rescue Twitter::Error::Forbidden => e
            # Maybe we sent the same message too soon
            logger.error "Forbidden from sending DM. Skipping! #{username}: #{message}\nException: #{e}"
        end
    end

    def send_email(username, message)
        # TODO: raise exception on failure
        puts "Sending e-mail to #{username}: #{message}"
    end

end
