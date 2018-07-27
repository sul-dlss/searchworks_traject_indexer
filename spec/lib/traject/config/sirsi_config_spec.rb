RSpec.describe 'Sirsi config' do
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:fixture_name) { 'idTests.mrc' }
  let(:record) { records.first }

  describe 'id' do
    subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }
    it do
      expect(results).to a_hash_including('id' => ['001suba'])
      expect(results).to a_hash_including('id' => ['001subaAnd004nosub'])
      expect(results).to a_hash_including('id' => ['001subaAnd004suba'])
      # TODO: Fix these
      # expect(results).not_to a_hash_including('id' => ['001noSubNo004'])
      # expect(results).not_to a_hash_including('id' => ['001and004nosub'])
      expect(results).not_to a_hash_including('id' => ['004noSuba'])
      expect(results).not_to a_hash_including('id' => ['004suba'])
    end
  end
end
