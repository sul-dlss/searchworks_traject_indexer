# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EmbeddingClient do
  subject(:client) do
    described_class.new(api_key: 'secret', base_url: 'https://gateway.example/v1/', http_client:)
  end

  let(:http_client) { instance_double(HTTPClient, post: response) }
  let(:response) do
    instance_double(
      HTTP::Message,
      status: 200,
      body: JSON.fast_generate(
        data: [{ index: 1, embedding: [0.3, 0.4] }, { index: 0, embedding: [0.1, 0.2] }]
      )
    )
  end

  it 'returns a validated batch in input order' do
    expect(client.embed(inputs: %w[first second], model: 'gemini-embedding-2', dimensions: 2))
      .to eq [[0.1, 0.2], [0.3, 0.4]]
  end

  it 'classifies quota responses as retryable' do
    allow(response).to receive_messages(status: 429, body: 'quota exceeded')

    expect { client.embed(inputs: ['first'], model: 'gemini-embedding-2', dimensions: 2) }
      .to raise_error(described_class::RetryableError, /HTTP 429/)
  end

  it 'rejects a response with the wrong vector dimensions' do
    expect { client.embed(inputs: %w[first second], model: 'gemini-embedding-2', dimensions: 3) }
      .to raise_error(described_class::Error, /not 3 numeric dimensions/)
  end
end
