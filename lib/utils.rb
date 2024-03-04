# frozen_string_literal: true

require 'logger'
require_relative '../config/boot'

module Utils
  def self.balance_parentheses(string)
    open_deletes = []
    close_deletes = []

    string.chars.each_with_index do |c, i|
      if c == '('
        open_deletes << i
      elsif c == ')'
        if open_deletes.length == 0
          close_deletes << i
        else
          open_deletes.pop
        end
      end
    end

    deletes = open_deletes
    deletes += close_deletes

    new_string = string.dup
    deletes.reverse.each do |i|
      new_string.slice!(i)
    end
    new_string
  end

  def self.longest_common_call_number_prefix(*strs)
    return '' if strs.empty?
    return strs.first if strs.one?

    min, max = strs.minmax
    idx = min.size.times { |i| break i if min[i] != max[i] }
    return min if idx == min.length

    substr = min[0...idx].sub(/V?(\s|[[:punct:]])+\z/, '')
    substr.sub(/(\s|[[:punct:]])+\z/, '')
  end

  def self.version
    @version ||= begin
      file = File.expand_path('../REVISION', __dir__)
      File.read(file) if File.exist?(file)
    end
  end

  def self.logger
    @logger ||= Logger.new($stderr)
  end

  def self.logger=(logger)
    @logger = logger
  end

  def self.set_log_file(file)
    @logger = Logger.new(file)
  end

  def self.kafka
    @kafka ||= Kafka.new(Settings.kafka.hosts, logger: Utils.logger)
  end

  def self.env_config
    Settings.environments[ENV.fetch('TRAJECT_ENV', nil)] || OpenStruct.new
  end
end
