# frozen_string_literal: true

require 'json'
require 'uri'

require 'httpclient'

class SolrEmbeddingCache
  class Error < StandardError
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  class RetryableError < Error; end

  FIELDS = %w[
    id
    embedding_input_hash_ss
    embedding_model_ss
    embedding_schema_version_ssi
    embedding_dimensions_is
    embedding_vector
  ].freeze

  def initialize(solr_url:, http_client: nil, timeout: 30, basic_auth_user: nil, basic_auth_password: nil)
    @url = URI.join(solr_url.end_with?('/') ? solr_url : "#{solr_url}/", 'get')
    @basic_auth = [basic_auth_user || @url.user, basic_auth_password || @url.password]
    @url.user = nil
    @url.password = nil
    @http_client = http_client || build_http_client(timeout)
    configure_auth
  end

  def vectors_for(jobs)
    return {} if jobs.empty?

    response = @http_client.get(@url, query(jobs))
    raise_for_status(response)

    documents = JSON.parse(response.body.to_s).dig('response', 'docs') || []
    expected = jobs.to_h { |job| [job.fetch('id').to_s, job] }

    documents.each_with_object({}) do |document, cached|
      id = value(document['id']).to_s
      job = expected[id]
      vector = document['embedding_vector']
      cached[id] = vector if job && matches?(document, job) && valid_vector?(vector, job)
    end
  rescue JSON::ParserError => e
    raise Error.new("invalid JSON from vector Solr: #{e.message}", body: response&.body.to_s)
  rescue HTTPClient::TimeoutError, HTTPClient::BadResponseError, IOError, SystemCallError => e
    raise RetryableError, "vector Solr cache request failed: #{e.message}"
  end

  private

  def build_http_client(timeout)
    HTTPClient.new.tap do |client|
      client.connect_timeout = timeout
      client.send_timeout = timeout
      client.receive_timeout = timeout
      client.ssl_config.set_default_paths
    end
  end

  def query(jobs)
    {
      'ids' => jobs.map { |job| escape(job.fetch('id')) }.join(','),
      'fl' => FIELDS.join(','),
      'wt' => 'json'
    }
  end

  def matches?(document, job)
    value(document['embedding_input_hash_ss']).to_s == job.fetch('input_hash').to_s &&
      value(document['embedding_model_ss']).to_s == job.fetch('model').to_s &&
      value(document['embedding_schema_version_ssi']).to_s == job.fetch('schema_version').to_s &&
      value(document['embedding_dimensions_is']).to_i == job.fetch('dimensions').to_i
  end

  def value(field)
    field.is_a?(Array) ? field.first : field
  end

  def valid_vector?(vector, job)
    vector.is_a?(Array) && vector.length == job.fetch('dimensions').to_i && vector.all?(Numeric)
  end

  def escape(value)
    value.to_s.gsub(/[\\,]/) { |character| "\\#{character}" }
  end

  def raise_for_status(response)
    return if response.status.to_i.between?(200, 299)

    error_class = retryable_status?(response.status) ? RetryableError : Error
    raise error_class.new(
      "vector Solr cache request failed with HTTP #{response.status}",
      status: response.status.to_i,
      body: response.body.to_s
    )
  end

  def retryable_status?(status)
    status.to_i == 408 || status.to_i == 429 || status.to_i >= 500
  end

  def configure_auth
    user, password = @basic_auth
    return unless user || password

    @http_client.set_auth(@url, URI.decode_www_form_component(user.to_s), URI.decode_www_form_component(password.to_s))
  end
end
