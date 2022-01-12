RSpec.describe 'Troublesome real-world data config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) { cached_indexer('./lib/traject/config/sirsi_config.rb') }
  let(:records) { MARC::XMLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { 'troublesomeRecords.xml'}
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'a record without any 008 (453316)' do
    subject(:result) { select_by_id('453316') }

    specify { expect(result['publication_year_isi']).to be_nil }
  end

  describe 'a record with extra space in the 245a field after punctuation is stripped' do
    subject(:result) { select_by_id('6412') }

    specify { expect(result['author_sort']).to eq ['Bernstein Leonard 19181990 Kaddish Symphony no 3 sound recording Kaddish'] }
    specify { expect(result['title_sort']).to eq ['Symphony no 3 sound recording Kaddish'] }
  end

end
