RSpec.describe 'IIIF Manifest config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) { cached_indexer('./lib/traject/config/sirsi_config.rb') }
  let(:fixture_name) { '10448954.marc' }
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  subject(:result) { indexer.map_record(record) }

  describe 'iiif_manifest_url_ssim' do
    it '' do
      expect(result['iiif_manifest_url_ssim']).to eq ['https://purl.stanford.edu/rj429xs9509/iiif/manifest']
    end
  end
end
