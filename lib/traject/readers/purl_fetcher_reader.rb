# frozen_string_literal: true

require 'faraday'
require 'progress_bar'

module Traject
  # A reader that fetches all items released to a target from purl-fetcher
  class PurlFetcherReader
    attr_reader :input_stream, :settings

    def initialize(input_stream, settings)
      @settings = Traject::Indexer::Settings.new settings
      @input_stream = input_stream
    end

    def each
      return to_enum(:each) unless block_given?

      response = client.get("/released/#{target}.json")
      records = JSON.parse(response.body)
      bar = ProgressBar.new(records.length)

      records.each do |record|
        yield PurlRecord.new(record['druid'].gsub('druid:', ''), purl_url: @settings['purl.url'], client:)
        bar.increment!
      end
    end

    private

    def target
      @settings['purl_fetcher.target'] || 'Searchworks'
    end

    def host
      @settings['purl_fetcher.url'] || 'https://purl-fetcher.stanford.edu'
    end

    def client
      @client ||= Faraday.new(url: host) do |builder|
        builder.adapter(:net_http_persistent, pool_size: @settings['processing_thread_pool'])
      end
    end
  end
end
