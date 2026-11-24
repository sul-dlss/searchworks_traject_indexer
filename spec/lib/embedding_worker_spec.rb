# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EmbeddingWorker do
  subject(:worker) do
    described_class.new(
      consumer:,
      client:,
      solr_writer:,
      batch_size:,
      logger:
    )
  end

  let(:consumer) do
    instance_double(
      Kafka::Consumer,
      each_batch: nil,
      mark_message_as_processed: nil,
      commit_offsets: nil
    )
  end
  let(:client) { instance_double(EmbeddingClient) }
  let(:solr_writer) { instance_double(SolrEmbeddingWriter, write: nil) }
  let(:logger) { instance_double(Logger, info: nil, error: nil) }
  let(:batch_size) { 100 }
  let(:messages) do
    [
      message_for(upsert_job('1', input: 'first')),
      message_for(upsert_job('2', input: 'second')),
      message_for(delete_job('3'))
    ]
  end
  let(:batch) { instance_double(Kafka::FetchedBatch, messages:) }

  before do
    allow(consumer).to receive(:each_batch).with(automatically_mark_as_processed: false).and_yield(batch)
    allow(client).to receive(:embed).and_return([[0.1, 0.2], [0.3, 0.4]])
  end

  it 'batches upserts and writes their vectors to Solr' do
    worker.run

    expect(client).to have_received(:embed).with(
      inputs: %w[first second],
      model: 'gemini-embedding-2',
      dimensions: 2
    )
    expect(solr_writer).to have_received(:write).with(
      [
        { job: hash_including('id' => '1'), vector: [0.1, 0.2] },
        { job: hash_including('id' => '2'), vector: [0.3, 0.4] }
      ],
      delete_ids: ['3']
    )
  end

  it 'commits the final input offset only after Solr succeeds' do
    expect(solr_writer).to receive(:write).ordered
    expect(consumer).to receive(:mark_message_as_processed).with(messages.last).ordered
    expect(consumer).to receive(:commit_offsets).ordered

    worker.run
  end

  it 'does not commit the input offset when vector creation fails' do
    allow(client).to receive(:embed).and_raise(EmbeddingClient::RetryableError, 'quota exceeded')

    expect { worker.run }.to raise_error(EmbeddingClient::RetryableError)
    expect(consumer).not_to have_received(:mark_message_as_processed)
    expect(consumer).not_to have_received(:commit_offsets)
    expect(solr_writer).not_to have_received(:write)
  end

  it 'does not commit the input offset when the vector Solr write fails' do
    allow(solr_writer).to receive(:write).and_raise(SolrEmbeddingWriter::Error, 'Solr unavailable')

    expect { worker.run }.to raise_error(SolrEmbeddingWriter::Error)
    expect(consumer).not_to have_received(:mark_message_as_processed)
    expect(consumer).not_to have_received(:commit_offsets)
  end

  context 'when a Kafka batch exceeds the embedding batch size' do
    let(:batch_size) { 1 }

    it 'processes and commits it in chunks' do
      allow(client).to receive(:embed).and_return([[0.1, 0.2]], [[0.3, 0.4]])
      messages.pop

      worker.run

      expect(client).to have_received(:embed).twice
      expect(solr_writer).to have_received(:write).twice
      expect(consumer).to have_received(:commit_offsets).twice
    end
  end

  describe 'a limited run' do
    it 'processes only the requested number of jobs and then returns' do
      expect(worker.run(limit: 2)).to eq 2

      expect(client).to have_received(:embed).with(
        inputs: %w[first second],
        model: 'gemini-embedding-2',
        dimensions: 2
      )
      expect(solr_writer).to have_received(:write).with(
        [
          { job: hash_including('id' => '1'), vector: [0.1, 0.2] },
          { job: hash_including('id' => '2'), vector: [0.3, 0.4] }
        ],
        delete_ids: []
      )
      expect(consumer).to have_received(:mark_message_as_processed).with(messages[1])
    end

    it 'rejects a non-positive limit' do
      expect { worker.run(limit: 0) }.to raise_error(ArgumentError, 'limit must be positive')

      expect(consumer).not_to have_received(:each_batch)
    end
  end

  it 'rejects a job whose ID does not match its Kafka key' do
    messages.replace([message_for(upsert_job('1'), key: 'different')])

    expect { worker.run }.to raise_error(ArgumentError, /does not match/)
    expect(client).not_to have_received(:embed)
    expect(consumer).not_to have_received(:commit_offsets)
  end

  it 'applies only the final operation for an ID within a chunk' do
    messages.replace(
      [
        message_for(delete_job('1')),
        message_for(upsert_job('1', input: 'replacement'))
      ]
    )
    allow(client).to receive(:embed).and_return([[0.5, 0.6]])

    worker.run

    expect(client).to have_received(:embed).with(
      inputs: ['replacement'],
      model: 'gemini-embedding-2',
      dimensions: 2
    )
    expect(solr_writer).to have_received(:write).with(
      [{ job: hash_including('id' => '1'), vector: [0.5, 0.6] }],
      delete_ids: []
    )
  end

  def upsert_job(id, input: 'text')
    {
      id:,
      operation: 'upsert',
      input:,
      input_hash: "sha256:#{id}",
      schema_version: 'searchworks-bib-v1',
      source: 'folio',
      model: 'gemini-embedding-2',
      dimensions: 2
    }
  end

  def delete_job(id)
    {
      id:,
      operation: 'delete',
      schema_version: 'searchworks-bib-v1',
      source: 'sdr'
    }
  end

  def message_for(job, key: job.fetch(:id))
    instance_double(
      Kafka::FetchedMessage,
      value: JSON.fast_generate(job),
      key:,
      topic: 'embedding-jobs',
      partition: 0,
      offset: Integer(job.fetch(:id))
    )
  end
end
