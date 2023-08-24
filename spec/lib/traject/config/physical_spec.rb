# frozen_string_literal: true

RSpec.describe 'Sirsi config' do
  subject(:result) { indexer.map_record(marc_to_folio(record)) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/folio_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }

  describe 'physical' do
    subject(:results) { records.map { |rec| indexer.map_record(marc_to_folio(rec)) }.to_a }
    let(:fixture_name) { 'physicalTests.mrc' }
    let(:field) { 'physical' }

    it 'has the correct physical descriptions' do
      result = select_by_id('300111')[field]
      expect(result).to eq ['1 sound disc (20 min.); analog, 33 1/3 rpm, stereo. ; 12 in.']

      result = select_by_id('300222')[field]
      expect(result).to eq ['271 p. : ill. ; 21 cm. + answer book.']

      result = select_by_id('300333')[field]
      expect(result).to eq ['records 1 box 2 x 4 x 3 1/2 ft.']

      result = select_by_id('300444')[field]
      expect(result).to eq ['diary 1 volume (463 pages) ; 17 cm. x 34.5 cm.']
    end

    context 'with displayFieldTests data' do
      let(:fixture_name) { 'displayFieldsTests.mrc' }

      it 'has the correct physical descriptions' do
        expect(select_by_id('3001')[field]).to eq ['1 sound disc (20 min.); analog, 33 1/3 rpm, stereo. ; 12 in.']
        expect(select_by_id('3002')[field]).to eq ['records 1 box 2 x 4 x 3 1/2 ft.']
        expect(select_by_id('3003')[field]).to eq ['17 boxes (7 linear ft.)']
        expect(select_by_id('3004')[field]).to eq ['poems 1 page ; 108 cm. x 34.5 cm.']
        expect(select_by_id('3005')[field]).to eq [
          '65 prints : relief process ; 29 x 22 cm.',
          '8 albums (550 photoprints) ; 51 x 46 cm. or smaller.'
        ]
      end
    end
  end

  describe 'vern_physical' do
    subject(:results) { records.map { |rec| indexer.map_record(marc_to_folio(rec)) }.to_a }
    let(:fixture_name) { 'vernacularSearchTests.mrc' }
    let(:field) { 'vern_physical' }

    it 'has the right fields mapped' do
      result = select_by_id('300VernSearch')[field]
      expect(result).to eq ['vern300a vern300b vern300c vern300e vern300f vern300g']
    end
  end
end
