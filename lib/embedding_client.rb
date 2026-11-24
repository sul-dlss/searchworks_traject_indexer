# frozen_string_literal: true

require 'json'
require 'httpclient'

# Calls the OpenAI-compatible embeddings endpoint exposed by the DLSS AI
# Gateway and validates that it returned one vector of the requested size for
# every input.
class EmbeddingClient
  DEFAULT_BASE_URL = 'https://dlss-aigateway-prod.stanford.edu/v1/'

  class Error < StandardError
    attr_reader :status, :body

    def initialize(message, status: nil, body: nil)
      @status = status
      @body = body
      super(message)
    end
  end

  class RetryableError < Error; end

  def initialize(api_key:, base_url: DEFAULT_BASE_URL, http_client: nil, timeout: 60)
    raise ArgumentError, 'LiteLLM API key is required' if api_key.to_s.empty?

    @api_key = api_key
    @url = "#{base_url.to_s.sub(%r{/+\z}, '')}/embeddings"
    @http_client = http_client || build_http_client(timeout)
  end

  def embed(inputs:, model:, dimensions:)
    dimensions = Integer(dimensions)
    raise ArgumentError, 'inputs must not be empty' if inputs.empty?
    raise ArgumentError, 'dimensions must be positive' unless dimensions.positive?

    response = post(model:, input: inputs, dimensions:, encoding_format: 'float')
    parse_vectors(response, count: inputs.length, dimensions:)
  end

  private

  def build_http_client(timeout)
    HTTPClient.new.tap do |client|
      client.connect_timeout = timeout
      client.receive_timeout = timeout
      client.send_timeout = timeout
      client.ssl_config.set_default_paths
    end
  end

  def post(body)
    @http_client.post(
      @url,
      JSON.fast_generate(body),
      'Authorization' => "Bearer #{@api_key}",
      'Content-Type' => 'application/json'
    ).tap do |response|
      next if response.status.to_i.between?(200, 299)

      error_class = retryable_status?(response.status.to_i) ? RetryableError : Error
      raise error_class.new(
        "AI Gateway returned HTTP #{response.status}: #{response.body.to_s.slice(0, 500)}",
        status: response.status.to_i,
        body: response.body.to_s
      )
    end
  rescue Error
    raise
  rescue StandardError => e
    raise RetryableError, "AI Gateway request failed: #{e.class}: #{e.message}"
  end

  def parse_vectors(response, count:, dimensions:)
    data = JSON.parse(response.body.to_s).fetch('data')
    vectors = data.sort_by { |item| Integer(item.fetch('index')) }
                  .map { |item| item.fetch('embedding') }

    raise Error, "AI Gateway returned #{vectors.length} vectors for #{count} inputs" unless vectors.length == count

    vectors.each do |vector|
      valid = vector.is_a?(Array) && vector.length == dimensions && vector.all?(Numeric)
      raise Error, "AI Gateway returned a vector that is not #{dimensions} numeric dimensions" unless valid
    end

    vectors
  rescue JSON::ParserError, KeyError, TypeError, ArgumentError => e
    raise Error, "Invalid AI Gateway response: #{e.message}"
  end

  def retryable_status?(status)
    status == 408 || status == 429 || status >= 500
  end
end
