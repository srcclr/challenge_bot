require 'logger'
require_relative 'multi_delegator'

module Logging
  def logger
    @logger ||= Logging.logger_for(self.class.name)
  end

  # Use a hash class-ivar to cache a unique Logger per class:
  @loggers = {}

  class << self
    def logger_for(classname)
      @loggers[classname] ||= configure_logger_for(classname)
    end

    def configure_logger_for(classname)
      log_file = File.open("#{__dir__}/../bot.log", 'a')
      #logger = Logger.new(MultiDelegator.delegate(:write, :close).to(STDOUT, log_file), 'weekly')
      logger = Logger.new("#{__dir__}/../bot.log", 'weekly')
      logger.progname = classname
      logger
    end
  end
end
