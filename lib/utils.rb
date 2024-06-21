# frozen_string_literal: true

require 'logger'
require_relative '../config/boot'

module Utils
  def self.encoding_cleanup(value)
    # cleans up cyrlic encoding i︠a︡ to i͡a
    # value.gsub(/\ufe20(.{1,2})\ufe21/, "\u0361\\1")
    value
  end

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
    return '' if strs.empty? || strs.one?

    min, max = strs.minmax
    return '' if min == max

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
    Settings.environments[env] || OpenStruct.new
  end

  def self.env
    @env ||= ENV.fetch('TRAJECT_ENV', nil)
  end

  def self.env=(env)
    @env = env
  end

  def self.in_blackout_period?
    return false unless env_config.blackout_periods.present?

    env_config.blackout_periods.none? do |period|
      (Time.parse(period['start'])..Time.parse(period['end'])).cover?(Time.now)
    end
  end
end
