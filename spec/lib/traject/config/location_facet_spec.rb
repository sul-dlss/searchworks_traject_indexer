# frozen_string_literal: true

RSpec.describe 'Location facet config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:folio_record) { marc_to_folio(MARC::Record.new) }
  let(:result) { indexer.map_record(folio_record) }
  let(:field) { 'location_facet' }
  let(:holdings) { [build(:lc_holding, additional_item_attributes: { location: { permanentLocation: permanent_location } })] }
  subject(:value) { result[field] }

  before do
    allow(folio_record).to receive(:index_items).and_return(holdings)
  end

  context 'with home location CURRICULUM' do
    let(:permanent_location) { { code: 'EDU-CURRICULUM' } }
    it { is_expected.to eq ['Curriculum Collection'] }
  end

  context 'with home location ARTLCKL-R' do
    let(:permanent_location) { { code: 'ART-LOCKED-LARGE' } }
    it { is_expected.to eq ['Art Locked Stacks'] }
  end

  context 'with any other home location' do
    let(:permanent_location) { { code: 'GRE-REFERENCE' } }
    it { is_expected.to be_nil }
  end
end
