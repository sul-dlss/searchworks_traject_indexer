RSpec.describe 'Speed benchmarks' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { '41022.marc' }

  describe 'initial speed' do
    it do
      expect { records.map { |rec| indexer.map_record(rec) }.to_a }
        .to perform_under(0.03).sec
    end
  end
end
