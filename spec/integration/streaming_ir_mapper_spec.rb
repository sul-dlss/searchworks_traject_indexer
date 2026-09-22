# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StreamingIndexer::IrMapper do
  let(:message) { double(topic: 'records', partition: 0, offset: 1, key: 'key', value: '{}') }

  it 'maps a Kafka FOLIO record with the existing FOLIO configuration' do
    client = instance_double(
      FolioClient,
      instance: {},
      items_and_holdings: {},
      statistical_codes: [],
      pieces: []
    )
    record = FolioRecord.new_from_source_record(
      JSON.parse(File.read(file_fixture('a14185492.json'))),
      client
    )
    mapper = described_class.new(
      config_path: './lib/traject/config/folio_config.rb',
      settings: { 'skip_empty_item_display' => '0' }
    )

    operation = mapper.map(SourceEvent.new(source: :folio, message:, record:))

    expect(operation).to have_attributes(action: :add, id: '14185492')
    expect(operation.document).to include('context_source_ssi' => ['folio'])
  end

  it 'maps a Kafka SDR record with the existing SDR configuration' do
    druid = 'sw705fr7011'
    collection_druid = 'vm093fg5170'
    record = PurlRecord.new(druid)
    stub_request(:get, "https://purl.stanford.edu/#{druid}.json")
      .to_return(status: 200, body: File.new(file_fixture("#{druid}.json")))
    stub_request(:get, "https://purl.stanford.edu/#{druid}.meta_json")
      .to_return(status: 200, body: File.new(file_fixture("#{druid}.meta_json")))
    stub_request(:get, "https://purl.stanford.edu/#{collection_druid}.json")
      .to_return(status: 200, body: File.new(file_fixture("#{collection_druid}.json")))
    allow(record).to receive(:catkey).and_return(nil)
    mapper = described_class.new(config_path: './lib/traject/config/sdr_config.rb')

    operation = mapper.map(SourceEvent.new(source: :sdr, message:, record:, id: druid))

    expect(operation).to have_attributes(action: :add, id: druid)
    expect(operation.document).to include('context_source_ssi' => ['sdr'])
  end
end
