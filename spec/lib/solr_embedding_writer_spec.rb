# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SolrEmbeddingWriter do
  subject(:writer) do
    described_class.new(
      vector_solr_url: 'https://solr.example/solr/searchworks-vectors',
      vector_field: 'semantic_vector',
      http_client:
    )
  end

  let(:http_client) { instance_double(HTTPClient) }
  let(:response) { instance_double(HTTP::Message, status: 200, body: '{}') }
  let(:job) do
    {
      'id' => '123',
      'input_hash' => 'sha256:abc',
      'schema_version' => 'searchworks-bib-v1',
      'model' => 'gemini-embedding-2',
      'source' => 'folio',
      'dimensions' => 2
    }
  end

  before do
    allow(http_client).to receive(:post).and_return(response)
  end

  it 'adds standalone documents to the vector collection' do
    writer.write([{ job:, vector: [0.1, 0.2] }])

    expect(http_client).to have_received(:post) do |url, body, headers|
      expect(url).to eq 'https://solr.example/solr/searchworks-vectors/update'
      expect(JSON.parse(body)).to eq(
        [
          {
            'id' => '123',
            'semantic_vector' => [0.1, 0.2],
            'embedding_input_hash_ss' => 'sha256:abc',
            'embedding_model_ss' => 'gemini-embedding-2',
            'embedding_schema_version_ssi' => 'searchworks-bib-v1',
            'embedding_source_ss' => 'folio',
            'embedding_dimensions_is' => 2
          }
        ]
      )
      expect(headers).to eq('Content-Type' => 'application/json')
    end
  end

  it 'deletes documents from the vector collection' do
    writer.write([], delete_ids: %w[123 456])

    expect(http_client).to have_received(:post) do |url, body, headers|
      expect(url).to eq 'https://solr.example/solr/searchworks-vectors/update'
      expect(JSON.parse(body)).to eq('delete' => %w[123 456])
      expect(headers).to eq('Content-Type' => 'application/json')
    end
  end

  it 'does not contact Solr for an empty chunk' do
    writer.write([], delete_ids: [])

    expect(http_client).not_to have_received(:post)
  end

  it 'raises when Solr rejects the update' do
    allow(response).to receive_messages(status: 409, body: 'document missing')

    expect { writer.write([{ job:, vector: [0.1, 0.2] }], delete_ids: []) }
      .to raise_error(described_class::Error, /HTTP 409/)
  end
end
