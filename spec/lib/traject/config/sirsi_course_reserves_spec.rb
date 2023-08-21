# frozen_string_literal: true

RSpec.describe 'Sirsi course reserves config' do
  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.settings('reserves_file' => 'spec/fixtures/files/multmult.csv')
      i.load_config_file('./lib/traject/config/marc_config.rb')
    end
  end

  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  let(:fixture_name) { '666.marc' }
  subject(:results) { records.map { |rec| indexer.map_record(stub_record_from_marc(rec)) }.to_a }
  subject(:result) { indexer.map_record(stub_record_from_marc(record)) }

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
      expect(result[field]).to eq ['36105041844338 -|- MUSIC -|- SCORES -|- GREEN-RESV -|- SCORE -|- M1048 .B41 C7 1973 -|- lc m   1048.000000 b0.410000 c0.700000 001973 -|- en~d~~~yzvr}zzzzzz~oz}vyzzzz~nz}szzzzz~zzyqsw~~~~~ -|- M1048 .B41 C7 1973 -|- lc m   1048.000000 b0.410000 c0.700000 001973 -|-  -|- LC -|- AMSTUD-214 -|- GREEN-RESV -|- 2-hour loan'] # rubocop:disable Layout/LineLength
    end
  end

  describe 'building_facet' do
    let(:indexer) do
      Traject::Indexer.new.tap do |i|
        i.settings('reserves_file' => 'spec/fixtures/files/rezdeskbldg.csv')
        i.load_config_file('./lib/traject/config/marc_config.rb')
      end
    end
    let(:field) { 'building_facet' }

    describe 'uses the Course Reserve rez_desk value instead of the item_display library value' do
      let(:fixture_name) { '9262146.marc' }
      it 'updates building_facet with crez info' do
        expect(result[field].length).to eq 2
        expect(result[field]).to include(
          'Engineering (Terman)',
          'Art & Architecture (Bowes)'
        )
      end
      context 'retain the library loc if only some items with that loc are overridden' do
        let(:fixture_name) { '8834492.marc' }
        it do
          expect(result[field].length).to eq 3
          expect(result[field]).to include(
            'Engineering (Terman)',
            'Green',
            'SAL3 (off-campus storage)'
          )
        end
      end
      context 'retain the library if the crez location is for the same library' do
        let(:fixture_name) { '9423045.marc' }
        it do
          expect(result[field].length).to eq 1
          expect(result[field]).to include(
            'Green'
          )
        end
      end
      context 'ignore a crez loc with no translation (use the library from item_display)' do
        let(:fixture_name) { '888.marc' }
        it do
          expect(result[field].length).to eq 1
          expect(result[field]).to include(
            'SAL3 (off-campus storage)'
          )
        end
      end
      context 'no building_facet' do
        let(:fixture_name) { '9434391.marc' }
        it do
          expect(result[field]).to be_nil
        end
      end
    end
  end
end
