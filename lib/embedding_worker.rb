# frozen_string_literal: true

require 'json'

# Consumes canonical embedding jobs in partition order, creates vectors in
# batches, and writes standalone documents to a dedicated vector Solr
# collection. Input offsets are committed only after Solr acknowledges every
# vector upsert and delete in a chunk.
class EmbeddingWorker
  DEFAULT_BATCH_SIZE = 100

  def initialize(consumer:, client:, solr_writer:, batch_size: DEFAULT_BATCH_SIZE, logger: Utils.logger)
    @consumer = consumer
    @client = client
    @solr_writer = solr_writer
    @batch_size = Integer(batch_size)
    @logger = logger

    raise ArgumentError, 'batch_size must be positive' unless @batch_size.positive?
  end

  def run(limit: nil)
    limit = Integer(limit) if limit
    raise ArgumentError, 'limit must be positive' if limit && !limit.positive?

    processed_count = 0
    @consumer.each_batch(automatically_mark_as_processed: false) do |batch|
      messages = limit ? batch.messages.first(limit - processed_count) : batch.messages
      messages.each_slice(@batch_size) { |chunk| process_chunk(chunk) }
      processed_count += messages.length

      break if limit && processed_count >= limit
    end

    processed_count
  end

  private

  def process_chunk(messages)
    jobs = latest_jobs(messages.map { |message| parse_job(message) })
    results = create_vectors(jobs)
    delete_ids = jobs.filter_map { |job| job.fetch('id') if job.fetch('operation') == 'delete' }
    @solr_writer.write(results, delete_ids:)

    @consumer.mark_message_as_processed(messages.last)
    @consumer.commit_offsets
    @logger.info(
      "Wrote #{results.length} vectors and #{delete_ids.length} deletes to Solr from #{messages.length} embedding jobs"
    )
  rescue StandardError => e
    message = messages.first
    @logger.error(
      "Embedding batch failed at #{message.topic}/#{message.partition}/#{message.offset}: #{e.class}: #{e.message}"
    )
    raise
  end

  def create_vectors(jobs)
    jobs.reject { |job| job.fetch('operation') == 'delete' }
        .group_by { |job| [job.fetch('model'), Integer(job.fetch('dimensions'))] }
        .flat_map do |((model, dimensions), grouped_jobs)|
      inputs = grouped_jobs.map { |job| job.fetch('input') }
      vectors = @client.embed(inputs:, model:, dimensions:)
      grouped_jobs.zip(vectors).map { |job, vector| { job:, vector: } }
    end
  end

  # A Kafka batch can contain more than one change for an ID. Only its final
  # operation belongs in the vector collection, and avoiding obsolete upserts
  # also avoids unnecessary embedding requests.
  def latest_jobs(jobs)
    jobs.to_h { |job| [job.fetch('id'), job] }.values
  end

  def parse_job(message)
    JSON.parse(message.value).tap do |job|
      raise ArgumentError, 'Embedding job ID does not match its Kafka key' unless job.fetch('id').to_s == message.key.to_s
      raise ArgumentError, "Unsupported embedding operation: #{job['operation']}" unless %w[upsert delete].include?(job['operation'])
    end
  rescue JSON::ParserError, KeyError => e
    raise ArgumentError, "Invalid embedding job: #{e.message}"
  end
end
