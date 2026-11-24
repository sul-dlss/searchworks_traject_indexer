# frozen_string_literal: true

# Creates vectors for canonical embedding jobs and writes them to the dedicated
# vector Solr collection. Sources such as Kafka and Solr are responsible for
# supplying jobs in appropriately sized batches.
class EmbeddingProcessor
  def initialize(client:, solr_writer:, logger: Utils.logger)
    @client = client
    @solr_writer = solr_writer
    @logger = logger
  end

  def process(jobs)
    jobs = latest_jobs(jobs)
    results = create_vectors(jobs)
    delete_ids = jobs.filter_map { |job| job.fetch('id') if job.fetch('operation') == 'delete' }
    @solr_writer.write(results, delete_ids:)

    @logger.info("Wrote #{results.length} vectors and #{delete_ids.length} deletes to Solr from #{jobs.length} embedding jobs")
  end

  private

  def create_vectors(jobs)
    jobs.reject { |job| job.fetch('operation') == 'delete' }
        .group_by { |job| [job.fetch('model'), Integer(job.fetch('dimensions'))] }
        .flat_map do |((model, dimensions), grouped_jobs)|
      inputs = grouped_jobs.map { |job| job.fetch('input') }
      vectors = @client.embed(inputs:, model:, dimensions:)
      grouped_jobs.zip(vectors).map { |job, vector| { job:, vector: } }
    end
  end

  # Only the final operation for an ID belongs in the vector collection.
  def latest_jobs(jobs)
    jobs.to_h { |job| [job.fetch('id'), job] }.values
  end
end
