RSpec.describe 'Holdings config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { '44794.marc' }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'on_order_library_ssim' do
    let(:field) { 'on_order_library_ssim' }

    it do
      expect(select_by_id('44794')[field]).to eq ['SAL3']
    end
  end
end
