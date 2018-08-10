describe 'Skips records' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.settings(
        'solr.url' => 'http://127.0.0.1:8983/solr/fake',
        'reader_class_name' => 'MARC::Reader',
        'writer_class_name' => 'Traject::ArrayWriter'
      )
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:results) { indexer.process_with(records, Traject::ArrayWriter.new).values }
  let(:fixture_name) { 'buildingTests.mrc' }
  it 'without an item_display field' do
    expect(results.count).to eq 41
    expect(records.count).to eq 45
  end
end
