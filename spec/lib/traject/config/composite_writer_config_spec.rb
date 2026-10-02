# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Composite writer configuration' do
  %w[folio sdr].each do |source|
    it "configures the #{source} indexer to write to Solr and Kafka when enabled" do
      indexer = Traject::Indexer.new('embedding.kafka.topic' => 'embedding-jobs')
      indexer.load_config_file("./lib/traject/config/#{source}_config.rb")

      expect(indexer.settings).to include(
        'writer_class_name' => 'Traject::SolrAndKafkaWriter',
        'embedding.kafka.topic' => 'embedding-jobs',
        'embedding.source' => source
      )
    end

    it "keeps the #{source} indexer Solr-only when embedding publication is not enabled" do
      indexer = Traject::Indexer.new
      indexer.load_config_file("./lib/traject/config/#{source}_config.rb")

      expect(indexer.settings['writer_class_name']).to eq 'Traject::SolrBetterJsonWriter'
    end
  end
end
