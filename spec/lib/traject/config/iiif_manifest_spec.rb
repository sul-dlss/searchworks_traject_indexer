# frozen_string_literal: true

RSpec.describe 'IIIF Manifest config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:fixture_name) { '10448954.json' }
  let(:records) { MARC::JSONLReader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  subject(:result) { indexer.map_record(marc_to_folio(record)) }

  before do
    stub_request(:get, 'https://purl.stanford.edu/xh235dd9059.meta_json').to_return(status: 200, body: {}.to_json)
  end

  describe 'iiif_manifest_url_ssim' do
    it '' do
      expect(result['iiif_manifest_url_ssim']).to eq ['https://purl.stanford.edu/rj429xs9509/iiif/manifest']
    end
  end
end
