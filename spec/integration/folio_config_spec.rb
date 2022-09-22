# frozen_string_literal: true

require 'spec_helper'

require 'folio_client'
require 'folio_record'

describe 'FOLIO indexing' do
  subject(:result) { indexer.map_record(folio_record) }

  let(:indexer) do
    Traject::Indexer.new('okapi.url' => 'https://example.com').tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end

  let(:folio_record) do
    FolioRecord.new_from_source_record(source_record_json, client)
  end

  let(:source_record_json) do
    JSON.parse(File.read(file_fixture('a14185492.json')))
  end

  let(:client) { instance_double(FolioClient) }

  before do
    allow(folio_record).to receive(:items_and_holdings).and_return({})
  end

  it 'maps the record with sirsi fields' do
    expect(result).to include 'title_display' => [start_with('Fantasia sopra motivi')]
  end

  it 'overwrites sirsi-specific fields' do
    expect(result).to include 'context_source_ssi' => ['folio'],
                              'collection' => %w[sirsi folio]
  end

  it 'includes folio-specific fields' do
    expect(result).to include 'uuid_ssi' => ['b2fe7336-33d1-5553-86cb-a15af14c7348'],
                              'folio_json_struct' => [start_with('{')],
                              'holdings_json_struct' => [start_with('{')]
  end

  context 'suppressed record' do
    let(:folio_record) do
      FolioRecord.new({ 'instance' => { 'hrid' => 'blah', 'suppressFromDiscovery' => true } })
    end

    it 'is skipped' do
      expect(result).to be_nil
    end
  end

  context 'cataloged dates' do
    context 'missing date' do
      before do
        folio_record.instance['catalogedDate'] = nil
      end

      it 'is not indexed' do
        expect(result).not_to include 'date_cataloged'
      end
    end

    context 'bad date from MARC' do
      before do
        folio_record.instance['catalogedDate'] = '19uu-uu-uu'
      end

      it 'is not indexed' do
        expect(result).not_to include 'date_cataloged'
      end
    end

    context 'normal date' do
      before do
        folio_record.instance['catalogedDate'] = '2007-05-11'
      end

      it 'is an ISO8601 timestamp in UTC' do
        expect(result['date_cataloged']).to eq ['2007-05-11T00:00:00Z']
      end
    end
  end
end
