# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EmbeddingClient do
  subject(:client) do
    described_class.new(
      api_key: 'secret',
      base_url: 'https://gateway.example/v1/',
      http_client:
    )
  end

  let(:http_client) { instance_double(HTTPClient) }
  let(:response) do
    instance_double(
      HTTP::Message,
      status: 200,
      body: JSON.fast_generate(
        data: [
          { index: 1, embedding: [0.3, 0.4] },
          { index: 0, embedding: [0.1, 0.2] }
        ]
      )
    )
  end

  before do
    allow(http_client).to receive(:post).and_return(response)
  end

  it 'requests a batch and returns vectors in input order' do
    vectors = client.embed(inputs: %w[first second], model: 'gemini-embedding-2', dimensions: 2)

    expect(vectors).to eq [[0.1, 0.2], [0.3, 0.4]]
    expect(http_client).to have_received(:post) do |url, body, headers|
      expect(url).to eq 'https://gateway.example/v1/embeddings'
      expect(JSON.parse(body)).to eq(
        'model' => 'gemini-embedding-2',
        'input' => %w[first second],
        'dimensions' => 2,
        'encoding_format' => 'float'
      )
      expect(headers).to eq(
        'Authorization' => 'Bearer secret',
        'Content-Type' => 'application/json'
      )
    end
  end

  it 'rejects a response with the wrong vector dimensions' do
    expect do
      client.embed(inputs: %w[first second], model: 'gemini-embedding-2', dimensions: 3)
    end.to raise_error(described_class::Error, /not 3 numeric dimensions/)
  end

  it 'identifies quota responses as retryable' do
    allow(response).to receive_messages(status: 429, body: 'quota exceeded')

    expect do
      client.embed(inputs: ['first'], model: 'gemini-embedding-2', dimensions: 2)
    end.to raise_error(described_class::RetryableError, /HTTP 429/)
  end

  it 'identifies network errors as retryable' do
    allow(http_client).to receive(:post).and_raise(HTTPClient::ConnectTimeoutError)

    expect do
      client.embed(inputs: ['first'], model: 'gemini-embedding-2', dimensions: 2)
    end.to raise_error(described_class::RetryableError, /request failed/)
  end

  it 'requires an API key' do
    expect { described_class.new(api_key: '') }.to raise_error(ArgumentError, /API key/)
  end
end
