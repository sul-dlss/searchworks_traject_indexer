describe 'Skips records' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.settings(
        'solr.url' => 'http://127.0.0.1:8983/solr/fake',
        'writer_class_name' => 'Traject::ArrayWriter',
        'skip_empty_item_display' => 1
      )
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:results) { indexer.process_with(records, Traject::ArrayWriter.new).values }
  let(:fixture_name) { 'buildingTests.mrc' }
  it 'without an item_display field' do
    expect(results.count).to eq 42
    expect(records.count).to eq 46
  end

  context 'with a **REQUIRED FILE** title' do
    let(:records) do
      [
        MARC::Record.new.tap do |r|
          r.append(
            MARC::DataField.new(
              '245',
              '1',
              '0',
              MARC::Subfield.new('a', '**REQUIRED FIELD**')
            )
          )
        end
      ]
    end

    it 'should be skipped' do
      expect(results.count).to eq 0
    end
  end
end
