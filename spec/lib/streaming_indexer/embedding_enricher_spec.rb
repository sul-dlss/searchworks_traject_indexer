# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StreamingIndexer::EmbeddingEnricher do
  subject(:enricher) do
    described_class.new({}, client:, cache:, retry_policy:, metrics:, logger:)
  end

  let(:client) { instance_double(EmbeddingClient) }
  let(:cache) { instance_double(SolrEmbeddingCache) }
  let(:metrics) do
    instance_double(
      StreamingIndexer::Metrics::Null,
      embedding_cache_hit: nil,
      embedding_cache_miss: nil,
      embedding_processed: nil
    )
  end
  let(:logger) { instance_double(Logger) }
  let(:retry_policy) do
    StreamingIndexer::RetryPolicy.new(
      max_attempts: 3,
      base_interval: 0,
      sleeper: class_double(Kernel, sleep: nil),
      random: Random.new(1)
    )
  end
  let(:message) { instance_double(Kafka::FetchedMessage) }
  let(:event) { SourceEvent.new(source: :folio, message:) }
  let(:first) do
    StreamingIndexer::Operation.add(
      id: '1',
      document: { 'id' => ['1'], 'title_full_display' => ['Cached title'], 'keyword_field' => ['current'] },
      event:
    )
  end
  let(:second) do
    StreamingIndexer::Operation.add(
      id: '2',
      document: { 'id' => ['2'], 'title_full_display' => ['New title'] },
      event:
    )
  end

  before do
    allow(cache).to receive(:vectors_for) do |jobs|
      { '1' => [0.1, 0.2] }.slice(*jobs.map { |job| job.fetch('id') })
    end
    allow(client).to receive(:embed).and_return([[0.3, 0.4]])
  end

  it 'copies cached vectors and generated vectors into complete mapped documents' do
    result = enricher.enrich([first, second])

    expect(result.failed).to be_empty
    expect(result.succeeded.map(&:document)).to contain_exactly(
      hash_including(
        'id' => ['1'],
        'keyword_field' => ['current'],
        'embedding_vector' => [0.1, 0.2],
        'embedding_model_ss' => 'gemini-embedding-2'
      ),
      hash_including('id' => ['2'], 'embedding_vector' => [0.3, 0.4])
    )
    expect(client).to have_received(:embed).with(
      inputs: ['title: New title | text:'], model: 'gemini-embedding-2', dimensions: 768
    )
  end

  it 'passes deletes through without querying the cache or gateway' do
    deletion = StreamingIndexer::Operation.delete(id: '1', event:)

    expect(enricher.enrich([deletion]).succeeded).to eq [deletion]
    expect(cache).not_to have_received(:vectors_for)
    expect(client).not_to have_received(:embed)
  end

  it 'retries transient gateway errors' do
    allow(cache).to receive(:vectors_for).and_return({})
    attempts = 0
    allow(client).to receive(:embed) do
      attempts += 1
      raise EmbeddingClient::RetryableError, 'busy' if attempts == 1

      [[0.3, 0.4]]
    end

    expect(enricher.enrich([second]).failed).to be_empty
    expect(client).to have_received(:embed).twice
  end

  it 'isolates a terminal embedding failure from other documents' do
    allow(cache).to receive(:vectors_for).and_return({})
    allow(client).to receive(:embed) do |inputs:, **|
      raise EmbeddingClient::Error, 'invalid input' if inputs.include?('title: Cached title | text:')

      [[0.3, 0.4]]
    end

    result = enricher.enrich([first, second])

    expect(result.succeeded.map(&:id)).to eq ['2']
    expect(result.failed.first).to have_attributes(id: '1', stage: :embedding, attempts: 3)
  end
end
