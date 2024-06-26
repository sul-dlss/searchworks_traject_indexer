# frozen_string_literal: true

module Traject
  class DruidReader
    attr_reader :input_stream, :settings

    def initialize(input_stream, settings)
      @settings = Traject::Indexer::Settings.new settings
      @input_stream = input_stream
    end

    def each
      return to_enum(:each) unless block_given?

      @input_stream.each_line do |druid|
        yield PurlRecord.new(druid.strip, purl_url: @settings['purl.url'])
      end
    end
  end
end
