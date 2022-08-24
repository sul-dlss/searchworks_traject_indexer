require 'kafka'
require 'kafka/statsd'
require_relative '../../folio_client'
require_relative '../../folio_record'

class Traject::KafkaFolioReader
  attr_reader :settings

  def initialize(input_stream, settings)
    @settings = Traject::Indexer::Settings.new settings
    @client = settings['folio.client'] || FolioClient.new
  end

  def each
    return to_enum(:each) unless block_given?

    kafka.each_message(max_bytes: 10000000) do |message|
      Utils.logger.debug("Traject::KafkaFolioReader#each(#{message.key})")
      record = JSON.parse(message.value)

      folio_record = if record.key? 'source_record'
                       FolioRecord.new_from_source_record(record, @client)
                     else
                       FolioRecord.new(record, @client)
                     end

      if folio_record.deleted?
        yield({ id: message.key, delete: true })
      else
        yield folio_record
      end
    end
  end

  private

  def kafka
    settings['kafka.consumer']
  end
end
