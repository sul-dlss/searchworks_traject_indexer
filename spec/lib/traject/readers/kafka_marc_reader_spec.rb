# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Traject::KafkaMarcReader do
  subject(:reader) { described_class.new(nil, 'kafka.consumer' => consumer, 'marc_source.type' => 'json') }
  let(:consumer) { double }

  before do
    allow(consumer).to receive(:instance_variable_get).with(:@fetcher).and_return(double(data?: true))
  end

  describe '#each' do
    context 'with deletes' do
      let(:delete_message) { double(key: '123', value: nil) }
      before do
        allow(consumer).to receive(:each_message).and_yield delete_message
      end

      it 'creates a record tagged for deletion' do
        expect(reader.each.to_a).to eq [{ id: '123', delete: true }]
      end
    end

    context 'with marc records' do
      let(:marc_message) { double(key: '123', value: File.read(file_fixture('444.json'))) }
      before do
        allow(consumer).to receive(:each_message).and_yield marc_message
      end

      it 'creates a record tagged for deletion' do
        res = reader.each.to_a
        expect(res.length).to eq 1
        expect(res).to include an_instance_of(MARC::Record)
        expect(res.first['001'].value).to eq 'a444'
      end
    end
  end
end
