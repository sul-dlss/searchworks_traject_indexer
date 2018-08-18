RSpec.describe 'Course reserves config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.settings('reserves_file' => 'spec/fixtures/files/multmult.csv')
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { '666.marc' }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'crez_instructor_search' do
    let(:field) { 'crez_instructor_search' }
    it do
      expect(result[field]).to eq ['Saldivar, Jose David']
    end
  end
  describe 'crez_course_name_search' do
    let(:field) { 'crez_course_name_search' }
    it do
      expect(result[field]).to eq ['What is Literature?']
    end
  end
  describe 'crez_course_id_search' do
    let(:field) { 'crez_course_id_search' }
    it do
      expect(result[field]).to eq ['COMPLIT-101']
    end
  end
  describe 'crez_desk_facet' do
    let(:field) { 'crez_desk_facet' }
    it do
      expect(result[field]).to eq ['Green Reserves']
    end
  end
  describe 'crez_dept_facet' do
    let(:field) { 'crez_dept_facet' }
    it do
      expect(result[field]).to eq ['Comparative Literature']
    end
  end
  describe 'crez_course_info' do
    let(:field) { 'crez_course_info' }
    it do
      expect(result[field]).to eq [
        'COMPLIT-101 -|- What is Literature? -|- Saldivar, Jose David'
      ]
    end
  end
  describe 'item_display' do
    let(:fixture_name) { '444.marc' }
    let(:field) { 'item_display' }
    it 'updates item_display with crez info' do
      # TODO: verify me!
      expect(result[field]).to eq ["36105041844338 -|- MUSIC -|- SCORES -|-  -|- SCORE -|-  -|-  -|-  -|- M1048 .B41 C7 1973 -|-  -|-  -|- LC"]
    end
  end

  describe 'building_facet' do
    let(:fixture_name) { '444.marc' }
    let(:field) { 'building_facet' }
    it 'updates building_facet with crez info' do
      result
    end
  end
end
