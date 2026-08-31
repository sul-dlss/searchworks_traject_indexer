# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StreamingIndexer::Runner do
  subject(:runner) do
    described_class.new(reader:, consumer:, mapper:, sink:, quarantine:, metrics:, notifier:)
  end

  let(:message) do
    double(topic: 'records', partition: 0, offset: 3, key: '123', value: '{}', create_time: Time.now)
  end
  let(:event) { SourceEvent.new(source: :folio, message:, record: :record, id: '123') }
  let(:operation) { StreamingIndexer::Operation.add(id: '123', document: { 'id' => '123' }, event:) }
  let(:reader) { double }
  let(:consumer) { double(mark_message_as_processed: nil, commit_offsets: nil, stop: nil) }
  let(:mapper) { double(map: operation) }
  let(:sink) do
    double(
      write: StreamingIndexer::SolrSink::Result.new(succeeded: [operation], failed: []),
      close: nil
    )
  end
  let(:quarantine) { double(write: nil, close: nil) }
  let(:metrics) do
    instance_double(
      StreamingIndexer::Metrics::Null,
      received: nil,
      processed: nil,
      skipped: nil,
      failed: nil,
      quarantined: nil,
      batch: nil,
      processing_time: nil
    )
  end
  let(:notifier) { class_double(Honeybadger, notify: nil) }

  before do
    allow(reader).to receive(:each_batch).with(automatically_mark_as_processed: false).and_yield([event])
  end

  it 'checkpoints only after Solr and quarantine acknowledge the batch' do
    order = []
    allow(sink).to receive(:write) do
      order << :solr
      StreamingIndexer::SolrSink::Result.new(succeeded: [operation], failed: [])
    end
    allow(quarantine).to receive(:write) { order << :quarantine }
    allow(consumer).to receive(:mark_message_as_processed) { order << :mark }

    runner.run

    expect(order).to eq %i[solr quarantine mark]
    expect(consumer).to have_received(:mark_message_as_processed).with(message)
    expect(consumer).not_to have_received(:commit_offsets)
  end

  it 'quarantines a failed item and continues processing unrelated operations' do
    bad_event = SourceEvent.new(source: :folio, message: double(topic: 'records', partition: 0, offset: 2, key: 'bad', value: 'bad'), error: JSON::ParserError.new('bad'))
    allow(reader).to receive(:each_batch).with(automatically_mark_as_processed: false).and_yield([bad_event, event])

    runner.run

    expect(sink).to have_received(:write).with([operation])
    expect(quarantine).to have_received(:write) do |failures|
      expect(failures.first).to have_attributes(stage: :source, error: bad_event.error)
    end
    expect(consumer).to have_received(:mark_message_as_processed).with(message)
  end

  it 'does not checkpoint if quarantine cannot acknowledge the failure' do
    bad_event = SourceEvent.new(source: :folio, message:, error: JSON::ParserError.new('bad'))
    allow(reader).to receive(:each_batch).with(automatically_mark_as_processed: false).and_yield([bad_event])
    allow(quarantine).to receive(:write).and_raise(RuntimeError, 'quarantine unavailable')

    expect { runner.run }.to raise_error(RuntimeError, 'quarantine unavailable')
    expect(consumer).not_to have_received(:mark_message_as_processed)
    expect(consumer).not_to have_received(:commit_offsets)
  end

  it 'asks the Kafka consumer to stop gracefully' do
    runner.stop

    expect(consumer).to have_received(:stop)
  end
end
