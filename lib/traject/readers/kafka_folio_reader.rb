# frozen_string_literal: true

require 'kafka'
require 'kafka/statsd'

# Reads messages out of Kafka and yields FolioRecords
class Traject::KafkaFolioReader
  attr_reader :settings

  def initialize(_input_stream, settings)
    @settings = Traject::Indexer::Settings.new settings
    @client = settings['folio.client']
  end

  def each
    return to_enum(:each) unless block_given?

    kafka.each_message(max_bytes: 10_000_000) do |message|
      Utils.logger.debug("Traject::KafkaFolioReader#each(#{message.key})")
      record = JSON.parse(Utils.encoding_cleanup(message.value))

      if record.key? 'parsedRecord'
        yield FolioRecord.new_from_source_record(record, @client)
      else
        yield FolioRecord.new(record, @client)
      end
    end
  end

  private

  def kafka
    settings['kafka.consumer']
  end
end
