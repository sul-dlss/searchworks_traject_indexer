# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Traject::FolioKafkaExtractor do
  subject(:extractor) { described_class.new(reader: [record], kafka:, topic: 'folio') }

  let(:record) { instance_double(FolioRecord, instance_id: '123', as_json: { 'instance' => { 'id' => '123' } }) }
  let(:kafka) { instance_double(Kafka::Client, async_producer: producer) }
  let(:producer) { instance_double(Kafka::AsyncProducer, deliver_messages: nil, shutdown: nil) }

  describe '#process!' do
    it 'generates JSON and produces it to Kafka' do
      expect(producer).to receive(:produce).with('{"instance":{"id":"123"}}', key: '123', topic: 'folio')

      expect(extractor.process!).to eq 1
    end
  end
end
