# frozen_string_literal: true

require 'kafka'
require 'kafka/statsd'

class Traject::KafkaPurlFetcherReader
  attr_reader :input_stream, :settings

  def initialize(input_stream, settings)
    @settings = Traject::Indexer::Settings.new settings
    @input_stream = input_stream
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
    Utils.logger.debug("Traject::KafkaPurlFetcherReader#read_message(#{message.key})")
    key_id = message.key.to_s.sub(/^druid:/, '')
    return delete_event(message, key_id) if message.value.nil?

    change = JSON.parse(Utils.encoding_cleanup(message.value))
    id = change.fetch('druid', key_id).sub('druid:', '')
    record = PurlRecord.new(id, purl_url: @settings['purl.url'])
    return delete_event(message, key_id) if should_be_deleted?(change, record)

    if selected_target?(change)
      SourceEvent.new(source: :sdr, message:, record:, id:)
    else
      SourceEvent.new(source: :sdr, message:, operation: :skip, id:)
    end
  rescue StandardError => e
    SourceEvent.new(source: :sdr, message:, id: message.key.to_s.sub(/^druid:/, ''), error: e)
  end

  private

  def kafka
    settings['kafka.consumer']
  end

  def target
    settings['purl_fetcher.target'] || 'Searchworks'
  end

  def skip_catkey
    settings.fetch('purl_fetcher.skip_catkey', true)
  end

  def should_be_deleted?(change, record)
    # Remove records that have the target explicitly set to false
    return true if target && change['false_targets'] && change['false_targets'].map(&:upcase).include?(target.upcase)

    if target.nil? || (change['true_targets'] && change['true_targets'].map(&:upcase).include?(target.upcase))
      # Remove changed records that now have a catkey
      return true if skip_catkey && (change['catkey'].presence || record.catkey)
      # Remove withdrawn records that are missing public cocina
      return true unless record.public_cocina?
    end

    false
  end

  def delete_event(message, id)
    SourceEvent.new(source: :sdr, message:, record: { id:, delete: true }, operation: :delete, id:)
  end

  def selected_target?(change)
    target.nil? || (change['true_targets'] && change['true_targets'].map(&:upcase).include?(target.upcase))
  end
end
