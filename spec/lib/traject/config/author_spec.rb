RSpec.describe 'Author config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { 'authorTests.mrc' }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'author_1xx_search' do
    let(:field) { 'author_1xx_search' }

    it 'has all subfields from 100' do
      result = select_by_id('100search')[field]
      expect(result).to eq ['100a 100b 100c 100d 100g 100j 100q 100u']
      expect(results).not_to include hash_including(field => ['100e'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'has all subfields from 110' do
      result = select_by_id('110search')[field]
      expect(result).to eq ['110a 110b 110c 110d 110g 110n 110u']
      expect(results).not_to include hash_including(field => ['110e'])
      expect(results).not_to include hash_including(field => ['110f'])
      expect(results).not_to include hash_including(field => ['110k'])
      expect(results).not_to include hash_including(field => ['none'])
    end

    it 'has all subfields from 111' do
      result = select_by_id('111search')[field]
      expect(result).to eq ['111a 111c 111d 111e 111g 111j 111n 111q 111u']
      expect(results).not_to include hash_including(field => ['111i'])
      expect(results).not_to include hash_including(field => ['none'])
    end
  end
end
