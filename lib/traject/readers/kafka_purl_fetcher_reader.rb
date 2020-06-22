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

    kafka.each_message(max_bytes: 10000000) do |message|
      Utils.logger.debug("Traject::KafkaPurlFetcherReader#each(#{message.key})")

      if message.value.nil?
        yield({ id: message.key, delete: true })
      else
        change = JSON.parse(message.value)
        record = PublicXmlRecord.new(change['druid'].sub('druid:', ''), purl_url: @settings['purl.url'])
        if should_be_deleted?(change, record)
          yield({ id: message.key, delete: true })
        elsif target.nil? || (change['true_targets'] && change['true_targets'].map(&:upcase).include?(target.upcase))
          yield record
        end
      end
    end
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
      # Remove withdrawn records that are missing public xml
      return true if !record.public_xml?
    end

    false
  end
end
