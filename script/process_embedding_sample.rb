#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config/boot'
require 'optparse'

config = Settings.embedding_worker
raise 'embedding_worker configuration is required' unless config

options = {
  limit: SolrEmbeddingSample::DEFAULT_LIMIT,
  query: '*:*',
  source_solr_url: ENV.fetch('SOLR_URL', nil)
}

OptionParser.new do |parser|
  parser.banner = 'Usage: bundle exec ruby script/process_embedding_sample.rb [options]'
  parser.on('--limit COUNT', Integer, 'Number of main Solr documents to process (default: 100)') do |limit|
    options[:limit] = limit
  end
  parser.on('--query QUERY', 'Solr query selecting the sample (default: *:*)') do |query|
    options[:query] = query
  end
  parser.on('--source-solr-url URL', 'Main SearchWorks collection URL (default: SOLR_URL)') do |url|
    options[:source_solr_url] = url
  end
end.parse!

client = EmbeddingClient.new(
  api_key: config.api_key,
  base_url: config.gateway_url
)
solr_writer = SolrEmbeddingWriter.new(
  vector_solr_url: config.vector_solr_url,
  vector_field: config.vector_field
)
processor = EmbeddingProcessor.new(client:, solr_writer:)
reader = SolrDocumentReader.new(
  solr_url: options[:source_solr_url],
  fields: SolrEmbeddingSample::DOCUMENT_FIELDS,
  query: options[:query],
  page_size: config.batch_size
)

SolrEmbeddingSample.new(reader:, processor:, batch_size: config.batch_size).run(limit: options[:limit])
