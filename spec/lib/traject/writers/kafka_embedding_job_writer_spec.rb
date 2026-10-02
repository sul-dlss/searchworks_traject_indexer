# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Traject::KafkaEmbeddingJobWriter do
  subject(:writer) { described_class.new(settings) }

  let(:producer) { instance_double(Kafka::Producer, produce: nil, deliver_messages: nil, shutdown: nil) }
  let(:logger) { instance_double(Logger, warn: nil) }
  let(:settings) do
    {
      'embedding.kafka.producer' => producer,
      'embedding.kafka.topic' => 'embedding-jobs',
      'embedding.source' => 'folio',
      'logger' => logger
    }
  end
  let(:context) do
    Traject::Indexer::Context.new.tap do |context|
      context.output_hash['id'] = ['123']
      context.output_hash['title_full_display'] = ['A title']
    end
  end

  it 'synchronously publishes a self-contained job keyed by document id' do
    writer.put(context)

    expect(producer).to have_received(:produce) do |json, options|
      expect(JSON.parse(json)).to include(
        'id' => '123',
        'operation' => 'upsert',
        'input' => 'title: A title | text:',
        'input_hash' => start_with('sha256:'),
        'schema_version' => 'searchworks-bib-v1',
        'source' => 'folio',
        'model' => 'gemini-embedding-2',
        'dimensions' => 768
      )
      expect(options).to eq(key: '123', topic: 'embedding-jobs')
    end
    expect(producer).to have_received(:deliver_messages)
  end

  it 'publishes skipped records as explicit delete jobs' do
    context.skip!('Delete')
    writer.put(context)

    expect(producer).to have_received(:produce) do |json, _options|
      expect(JSON.parse(json)).to include('id' => '123', 'operation' => 'delete')
      expect(JSON.parse(json)).not_to have_key('input')
    end
  end

  it 'does not publish records without an id' do
    context.output_hash.delete('id')
    writer.put(context)

    expect(producer).not_to have_received(:produce)
    expect(logger).to have_received(:warn).with(/without an id/)
  end

  it 'propagates delivery failures so the source message is not acknowledged' do
    allow(producer).to receive(:deliver_messages).and_raise(Kafka::DeliveryFailed.new('failed', []))

    expect { writer.put(context) }.to raise_error(Kafka::DeliveryFailed)
  end

  it 'identifies that skipped records should be written' do
    expect(writer.write_skipped_records?).to be true
  end

  it 'shuts down the producer when closed' do
    writer.close

    expect(producer).to have_received(:shutdown)
  end

  context 'when building its producer' do
    let(:kafka) { instance_double(Kafka::Client, producer:) }

    before do
      settings.delete('embedding.kafka.producer')
      settings['embedding.kafka'] = kafka
    end

    it 'requires acknowledgements from all in-sync Kafka replicas' do
      writer

      expect(kafka).to have_received(:producer).with(
        required_acks: :all,
        ack_timeout: 10,
        max_retries: 5,
        retry_backoff: 5,
        compression_codec: :gzip
      )
    end
  end
end
