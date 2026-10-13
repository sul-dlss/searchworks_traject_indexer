# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Traject::KafkaFolioReader do
  subject(:reader) { described_class.new('', 'kafka.consumer' => consumer) }

  let(:consumer) { double }

  describe '#read_message' do
    it 'returns a source event containing a FolioRecord' do
      message = double(key: 'uuid', value: File.read(file_fixture('a14185492.json')))

      event = reader.read_message(message)

      expect(event).to have_attributes(source: :folio, operation: :upsert, message:)
      expect(event.record).to be_a(FolioRecord)
    end

    it 'turns a Kafka tombstone into a delete event' do
      message = double(key: '123', value: nil)

      expect(reader.read_message(message)).to have_attributes(operation: :delete, id: '123')
    end

    it 'retains malformed messages as failed source events' do
      message = double(key: '123', value: '{')

      expect(reader.read_message(message)).to have_attributes(id: '123', failed?: true)
    end
  end

  describe '#each_batch' do
    it 'does not allow Kafka to mark the batch automatically when requested' do
      message = double(key: '123', value: nil, is_control_record: false)
      batch = double(messages: [message])
      allow(consumer).to receive(:each_batch)
        .with(max_bytes: 10_000_000, automatically_mark_as_processed: false)
        .and_yield(batch)

      expect(reader.each_batch(automatically_mark_as_processed: false).first.first).to have_attributes(id: '123')
    end
  end
end
