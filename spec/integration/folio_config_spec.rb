require 'spec_helper'

require 'folio_client'
require 'folio_record'

describe 'SDR indexing' do
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
    allow(folio_record).to receive(:reserves).and_return([])
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
      FolioRecord.new({ 'instance' => {'hrid' => 'blah', 'suppressFromDiscovery' => true } })
    end

    it 'is skipped' do
      expect(result).to be_nil
    end
  end
end
