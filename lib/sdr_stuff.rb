require 'purl_fetcher/client'

class SdrReader
  attr_reader :input_stream

  # @param input_stream [File|IO]
  # @param settings [Traject::Indexer::Settings]
  def initialize(input_stream, settings)
    @settings = Traject::Indexer::Settings.new settings
    @input_stream = input_stream
  end

  def each(*args, &block)
    input_stream.each_line do |druid|
      yield PublicXmlRecord.new(druid, purl_url: @settings['purl.url'])
    end
  end
end

class PublicXmlRecord < PurlFetcher::Client::PublicXmlRecord
  mods_xml_source do |model|
    model.mods.to_s
  end
  configure_mods_display do
  end

  def purl_url
    @options[:purl_url]
  end
end
