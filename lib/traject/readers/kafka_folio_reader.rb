require 'kafka'
require 'kafka/statsd'
require_relative '../../folio_record'

class Traject::KafkaFolioReader
  attr_reader :settings

  def initialize(input_stream, settings)
    @settings = Traject::Indexer::Settings.new settings
  end

  def each
    return to_enum(:each) unless block_given?

    kafka.each_message(max_bytes: 10000000) do |message|
      Utils.logger.debug("Traject::KafkaFolioReader#each(#{message.key})")
      record = JSON.parse(message.value)

      if record.key? 'source_record'
        yield FolioRecord.new_from_source_record(record['source_record'])
      else
        yield FolioRecord.new(record)
      end
    end
  end

  private

  def kafka
    settings['kafka.consumer']
  end
end
