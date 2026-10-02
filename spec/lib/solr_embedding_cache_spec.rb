# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SolrEmbeddingCache do
  subject(:cache) { described_class.new(solr_url: 'https://solr.example/solr/searchworks', http_client:) }

  let(:http_client) { instance_double(HTTPClient, get: response) }
  let(:response) { instance_double(HTTP::Message, status: 200, body: JSON.fast_generate(response: { docs: })) }
  let(:docs) do
    [
      {
        id: '1',
        embedding_input_hash_ss: ['sha256:same'],
        embedding_model_ss: 'gemini-embedding-2',
        embedding_schema_version_ssi: 'searchworks-bib-v1',
        embedding_dimensions_is: 2,
        embedding_vector: [0.1, 0.2]
      },
      {
        id: '2',
        embedding_input_hash_ss: 'sha256:old',
        embedding_model_ss: 'gemini-embedding-2',
        embedding_schema_version_ssi: 'searchworks-bib-v1',
        embedding_dimensions_is: 2,
        embedding_vector: [0.3, 0.4]
      }
    ]
  end
  let(:jobs) do
    %w[1 2].map do |id|
      {
        'id' => id,
        'input_hash' => 'sha256:same',
        'model' => 'gemini-embedding-2',
        'schema_version' => 'searchworks-bib-v1',
        'dimensions' => 2
      }
    end
  end

  it 'hits only when all embedding identity metadata matches' do
    expect(cache.vectors_for(jobs)).to eq('1' => [0.1, 0.2])
    expect(http_client).to have_received(:get) do |url, params|
      expect(url.to_s).to eq 'https://solr.example/solr/searchworks/get'
      expect(params['ids']).to eq '1,2'
    end
  end

  it 'does not contact Solr for an empty batch' do
    expect(cache.vectors_for([])).to be_empty
    expect(http_client).not_to have_received(:get)
  end

  it 'classifies server failures as retryable' do
    allow(response).to receive_messages(status: 503, body: 'unavailable')

    expect { cache.vectors_for(jobs) }.to raise_error(described_class::RetryableError, /HTTP 503/)
  end

  it 'does not retry a malformed successful response' do
    allow(response).to receive(:body).and_return('{')

    expect { cache.vectors_for(jobs) }.to raise_error(described_class::Error, /invalid JSON/)
  end
end
