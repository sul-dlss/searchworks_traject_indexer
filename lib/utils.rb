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

  # Extract century and decade from year.
  # "Obsolete. to take a tenth of or from." - https://www.dictionary.com/browse/decimate
  #
  # @param maybe_year [Integer] an int that (hopefully) represents a year
  def self.centimate_and_decimate(maybe_year)
    parsed_date = Date.new(maybe_year)
    [century_from_date(parsed_date), decade_from_date(parsed_date)]
  rescue Date::Error
    %w[unknown_century unknown_decade] # guess not
  end

  # Given a Date, return a String for the century that contains it.
  #
  # This uses the colloquial grouping of centuries, because it's more intuitive at a glance, and the code is easier:
  # https://en.wikipedia.org/wiki/Century#Start_and_end_of_centuries
  #
  # @param date [Date] a Date object on which we can call strftime
  # @return [String] a String representing the century in which the date belongs (e.g. 1500-1599)
  def self.century_from_date(date)
    date.strftime('%C00-%C99')
  end

  # Given a Date, return a String for the decade that contains it.
  #
  # This uses the more colloquial/popular decade boundary, because it's easier to code and more intuitive for users.
  # https://en.wikipedia.org/wiki/Decade#0-to-9_decade
  #
  # @param date [Date] a Date object on which we can call strftime
  # @return [String] a String representing the decade in which the date belongs (e.g. 1990-1999)
  def self.decade_from_date(date)
    decade_prefix = (date.strftime('%Y').to_i / 10).to_s
    "#{decade_prefix}0-#{decade_prefix}9"
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

    env_config.blackout_periods.any? do |period|
      (Time.parse(period['start'])..Time.parse(period['end'])).cover?(Time.now)
    end
  end
end
