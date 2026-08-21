#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../config/boot'

config = Settings.embedding_worker
raise 'embedding_worker configuration is required' unless config

kafka = Kafka.new(Settings.kafka.hosts, logger: Utils.logger)
consumer = kafka.consumer(group_id: config.consumer_group_id)
consumer.subscribe(config.input_topic, start_from_beginning: true)

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

worker.run
