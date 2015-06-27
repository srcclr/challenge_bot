
class OutgoingHandler

    def initialize(db)
        @db = db
    end

    def handle
        msg = @db.pop_dm
        return if msg.nil?

        puts "SEND #{msg[:username]}: #{msg[:message]}"
    end

end
