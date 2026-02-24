# frozen_string_literal: true

module Traject
  class DruidReader
    attr_reader :input_stream, :settings

    def initialize(input_stream, settings)
      @settings = Traject::Indexer::Settings.new settings
      @input_stream = input_stream

      # This reader is only used in development and doesn't need to report
      # anything to Honeybadger, so we silence it
      Honeybadger.configure { it.env = 'development' }
    end

    def each
      return to_enum(:each) unless block_given?

      @input_stream.each_line do |druid|
        yield PurlRecord.new(druid.strip, purl_url: @settings['purl.url'])
      end
    end
  end
end
