# frozen_string_literal: true

require 'json'

# Writes generated vectors as standalone documents in a dedicated Solr
# collection. Upserts replace vector documents with the same ID, and delete
# jobs remove the corresponding document from the vector collection.
class SolrEmbeddingWriter
  DEFAULT_VECTOR_FIELD = 'embedding_vector'

  class Error < StandardError; end

  def initialize(vector_solr_url:, vector_field: DEFAULT_VECTOR_FIELD, http_client: nil, timeout: 60)
    raise ArgumentError, 'Vector Solr URL is required' if vector_solr_url.to_s.empty?
    raise ArgumentError, 'Solr vector field is required' if vector_field.to_s.empty?

    @url = "#{vector_solr_url.to_s.sub(%r{/+\z}, '')}/update"
    @vector_field = vector_field
    @http_client = http_client || HTTPClient.new.tap do |client|
      client.connect_timeout = timeout
      client.receive_timeout = timeout
      client.send_timeout = timeout
    end
  end

  def write(results, delete_ids: [])
    add_documents(results) unless results.empty?
    delete_documents(delete_ids) unless delete_ids.empty?
  rescue Error
    raise
  rescue StandardError => e
    raise Error, "Solr embedding update failed: #{e.class}: #{e.message}"
  end

  private

  def add_documents(results)
    response = @http_client.post(
      @url,
      JSON.fast_generate(results.map { |result| vector_document(result) }),
      'Content-Type' => 'application/json'
    )
    validate_response(response)
  end

  def delete_documents(ids)
    response = @http_client.post(
      @url,
      JSON.fast_generate('delete' => ids),
      'Content-Type' => 'application/json'
    )
    validate_response(response)
  end

  def vector_document(result)
    job = result.fetch(:job)
    {
      'id' => job.fetch('id'),
      @vector_field => result.fetch(:vector),
      'embedding_input_hash_ssi' => job.fetch('input_hash'),
      'embedding_model_ssi' => job.fetch('model'),
      'embedding_schema_version_ssi' => job.fetch('schema_version'),
      'embedding_source_ssi' => job.fetch('source'),
      'embedding_dimensions_isi' => Integer(job.fetch('dimensions'))
    }
  end

  def validate_response(response)
    return if response.status.to_i.between?(200, 299)

    raise Error, "Solr returned HTTP #{response.status}: #{response.body.to_s.slice(0, 500)}"
  end
end
