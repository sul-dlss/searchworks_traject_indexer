#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config/boot'
require 'optparse'

config = Settings.embedding_worker
raise 'embedding_worker configuration is required' unless config

options = {
  consumer_group_id: config.consumer_group_id,
  input_topic: config.input_topic
}

OptionParser.new do |parser|
  parser.banner = 'Usage: bundle exec ruby script/process_embedding_jobs.rb [options]'
  parser.on('--limit COUNT', Integer, 'Stop after processing COUNT embedding jobs') do |limit|
    options[:limit] = limit
  end
  parser.on('--consumer-group-id ID', 'Override the configured Kafka consumer group') do |consumer_group_id|
    options[:consumer_group_id] = consumer_group_id
  end
  parser.on('--input-topic TOPIC', 'Override the configured Kafka input topic') do |input_topic|
    options[:input_topic] = input_topic
  end
end.parse!

kafka = Kafka.new(Settings.kafka.hosts, logger: Utils.logger)
consumer = kafka.consumer(group_id: options.fetch(:consumer_group_id))
consumer.subscribe(options.fetch(:input_topic), start_from_beginning: true)

worker = EmbeddingWorker.new(
  consumer:,
  client: EmbeddingClient.new(
    api_key: config.api_key,
    base_url: config.gateway_url
  ),
  solr_writer: SolrEmbeddingWriter.new(
    vector_solr_url: config.vector_solr_url,
    vector_field: config.vector_field
  ),
  batch_size: config.batch_size
)

Signal.trap('TERM') { consumer.stop }
Signal.trap('INT') { consumer.stop }

worker.run(limit: options[:limit])
