# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StreamingIndexer::IrMapper do
  subject(:mapper) { described_class.new(indexer:) }

  let(:logger) { Logger.new(nil) }
  let(:indexer) do
    instance_double(
      Traject::Indexer,
      settings: Traject::Indexer::Settings.new,
      source_record_id_proc: nil,
      logger:
    )
  end
  let(:message) { double(key: 'key') }
  let(:event) { SourceEvent.new(source: :folio, message:, record: :record) }

  it 'returns a normalized add operation' do
    allow(indexer).to receive(:map_to_context!) do |context|
      context.output_hash['id'] = ['123']
      context.output_hash['title'] = ['A title']
    end

    operation = mapper.map(event)

    expect(operation).to have_attributes(action: :add, id: '123')
    expect(operation.document).to include('id' => '123', 'title' => ['A title'])
  end

  it 'turns a mapped skip with an id into a delete' do
    allow(indexer).to receive(:map_to_context!) do |context|
      context.output_hash['id'] = ['123']
      context.skip!('Delete')
    end

    expect(mapper.map(event)).to have_attributes(action: :delete, id: '123')
  end

  it 'returns no operation for an intentional skip without an id' do
    allow(indexer).to receive(:map_to_context!) do |context|
      context.skip!('Incomplete record')
    end

    expect(mapper.map(event)).to be_nil
  end

  it 'rejects records without exactly one non-empty id' do
    allow(indexer).to receive(:map_to_context!) do |context|
      context.output_hash['id'] = ['', '123']
    end

    expect { mapper.map(event) }.not_to raise_error

    allow(indexer).to receive(:map_to_context!) do |context|
      context.output_hash['id'] = %w[123 456]
    end
    expect { mapper.map(event) }.to raise_error(StreamingIndexer::InvalidRecord)
  end

  it 'does not run the mapping for explicit deletes' do
    delete_event = SourceEvent.new(source: :sdr, message:, operation: :delete, id: 'abc')

    expect(mapper.map(delete_event)).to have_attributes(action: :delete, id: 'abc')
  end
end
