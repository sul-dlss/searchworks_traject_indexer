# frozen_string_literal: true

require 'kafka'
require 'kafka/statsd'
require 'active_support'

class Traject::KafkaMarcReader
  attr_reader :settings

  def initialize(_input_stream, settings)
    @settings = Traject::Indexer::Settings.new settings
  end

  def each(&)
    return to_enum(:each) unless block_given?

    kafka.each_message(max_bytes: 10_000_000) do |message|
      Utils.logger.debug("Traject::KafkaMarcReader#each(#{message.key})")

      if message.value.nil?
        yield({ id: message.key, delete: true })
      else
        Traject::MarcCombiningReader.new(StringIO.new(message.value), settings).each(&)
      end
    end
  end

  private

  def kafka
    settings['kafka.consumer']
  end
end
