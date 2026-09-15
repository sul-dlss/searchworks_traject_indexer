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

    each_event do |event|
      raise event.error if event.failed?

      yield event.record unless event.skip?
    end
  end

  def each_event(automatically_mark_as_processed: true)
    return to_enum(:each_event, automatically_mark_as_processed:) unless block_given?

    kafka.each_message(max_bytes: 10_000_000, automatically_mark_as_processed:) do |message|
      yield read_message(message)
    end
  end

  def each_batch(automatically_mark_as_processed: true)
    return to_enum(:each_batch, automatically_mark_as_processed:) unless block_given?

    kafka.each_batch(max_bytes: 10_000_000, automatically_mark_as_processed:) do |batch|
      messages = batch.messages.reject { |message| message.respond_to?(:is_control_record) && message.is_control_record }
      yield messages.map { |message| read_message(message) }
    end
  end

  def read_message(message)
    Utils.logger.debug("Traject::KafkaFolioReader#read_message(#{message.key})")
    return SourceEvent.new(source: :folio, message:, operation: :delete, id: message.key) if message.value.nil?

    raw_record = JSON.parse(Utils.encoding_cleanup(message.value))
    return SourceEvent.new(source: :folio, message:, operation: :delete, id: raw_record['id'] || message.key) if raw_record['delete']

    record = if raw_record.key? 'parsedRecord'
               FolioRecord.new_from_source_record(raw_record, @client)
             else
               FolioRecord.new(raw_record, @client)
             end
    SourceEvent.new(source: :folio, message:, record:, id: canonical_id(record))
  rescue StandardError => e
    SourceEvent.new(source: :folio, message:, id: message.key, error: e)
  end

  private

  def kafka
    settings['kafka.consumer']
  end

  def canonical_id(record)
    id = record.hrid
    id = record['001']&.value if id.to_s.empty?
    id&.sub(/^a/, '')
  rescue StandardError
    nil
  end
end
