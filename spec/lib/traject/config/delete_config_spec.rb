RSpec.describe 'Delete config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/delete_config.rb')
    end
  end
  let(:record) { { id: '463838', delete: true } }
  let(:field) { 'id' }

  describe 'id' do
    it do
      expect(result[field]).to eq ['463838']
    end
  end
end
