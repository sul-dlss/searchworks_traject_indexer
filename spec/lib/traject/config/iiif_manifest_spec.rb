# frozen_string_literal: true

RSpec.describe 'IIIF Manifest config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/marc_config.rb')
    end
  end
  let(:fixture_name) { '10448954.marc' }
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  subject(:result) { indexer.map_record(stub_record_from_marc(record)) }

  describe 'iiif_manifest_url_ssim' do
    it '' do
      expect(result['iiif_manifest_url_ssim']).to eq ['https://purl.stanford.edu/rj429xs9509/iiif/manifest']
    end
  end
end
