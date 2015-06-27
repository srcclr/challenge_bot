
class OutgoingHandler

    def initialize(db, client)
        @db = db
        @client = client
    end

    def handle
        dm = @db.peek_dm
        return if dm.nil?

        puts "SEND #{dm[:username]}: #{dm[:message]}"
        client.create_direct_message(dm[:username], dm[:message])
        dm.destroy
    end

end
