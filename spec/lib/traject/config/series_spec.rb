RSpec.describe 'Series config' do
  extend ResultHelpers
  subject(:result) { indexer.map_record(record) }

  let(:indexer) do
    Traject::Indexer.new.tap do |i|
      i.load_config_file('./lib/traject/config/sirsi_config.rb')
    end
  end
  let(:records) { MARC::Reader.new(file_fixture(fixture_name).to_s).to_a }
  let(:record) { records.first }
  subject(:results) { records.map { |rec| indexer.map_record(rec) }.to_a }

  describe 'series_search' do
    let(:field) { 'series_search' }
    let(:fixture_name) { 'seriesTests.mrc' }

    it do
      # include 490v per Vitus email of 2011-03-10
      expect(select_by_id('490')[field]).to eq ['490a 490v']

      %w[1943665 1943753].each do |id|
        expect(select_by_id(id)[field]).to include(/Publications of the European Court of Human Rights. Series A, Judgments and decisions/)
      end

      # 490a 440a
      %w[797438 798059].each do |id|
        expect(select_by_id(id)[field]).to include(/Joyce, James, 1882-1941. James Joyce archive/)
      end
      # phrase in title, no series fields
      expect(select_by_id('2222')[field]).to be_nil

      # 490aav, 810atnpv
      %w[1943665 1943753].each do |id|
        expect(select_by_id(id)[field]).to include(/European Court of Human Rights./)
        expect(select_by_id(id)[field]).to include(/European Court of Human Rights. Publications de la Cour europeenne des droits de l'homme. Serie A, Arrets et decisions/)
      end
      # phrase in title, no series fields
      expect(select_by_id('1111')[field]).to be_nil
      # sub v included
      expect(select_by_id('1943665')[field][0]).to include '138'
      expect(select_by_id('1943753')[field][0]).to include '132'

      # 490av, 811atv
      %w[1588366 253693].each do |id|
        expect(select_by_id(id)[field]).to include(/Delaware Symposium on Language Studies/)
      end
      # phrase in title, no series fields
      expect(select_by_id('9999')[field]).to be_nil
      # sub v included
      expect(select_by_id('1588366')[field][0]).to include '4'
      expect(select_by_id('253693')[field][0]).to include '7'

      # 490av, 830av
      %w[1964873 4489006 408434 488433].each do |id|
        expect(select_by_id(id)[field]).to include(/Lecture notes in computer science/)
      end
      # phrase in title, no series fields
      expect(select_by_id('4444')[field]).to be_nil
      # sub v included
      expect(select_by_id('1964873')[field][0]).to include '240'
      expect(select_by_id('4489006')[field][0]).to include '1658'
      expect(select_by_id('408434')[field][0]).to include '28'

      # 490av, 830av 440axv
      %w[1025630 1554950].each do |id|
        expect(select_by_id(id)[field]).to include(/Beitrage zur Afrikakunde/)
      end
      # phrase in title, no series fields
      expect(select_by_id('6666')[field]).to be_nil
      # sub v included
      expect(select_by_id('1025630')[field][0]).to include '3'
      expect(select_by_id('1554950')[field][0]).to include '6'
      # "Macmillan series in applied computer science"  490, 830
      expect(select_by_id('1173521')[field][0]).to include 'Macmillan series in applied computer science'
      # phrase in title, no series fields
      expect(select_by_id('3333')[field]).to be_nil
    end
  end
  describe 'vern_series_search' do
    let(:field) { 'vern_series_search' }
    let(:fixture_name) { 'vernSeriesTests.mrc' }

    it 'does not map vernacular data into the series or series_exact fields' do
      expect(select_by_id('vern490')['series_search']).to eq ['490a']
      expect(select_by_id('vern830')['series_exact_search']).to eq ['830a']
    end

    specify do
      expect(select_by_id('vern490')[field]).to eq ['vern490a vern490v']

      expect(select_by_id('vern440')[field]).to eq ['vern440a vern440n vern440p vern440v']

      expect(select_by_id('vern800')[field]).to eq ['vern800a vern800d vern800f vern800g vern800h vern800j vern800k vern800l vern800m vern800n vern800o vern800p vern800r vern800s vern800t vern800v vern800x']

      expect(select_by_id('vern810')[field]).to eq ['vern810a vern810d vern810f vern810g vern810h vern810j vern810k vern810l vern810m vern810n vern810o vern810p vern810r vern810s vern810t vern810v vern810x']

      expect(select_by_id('vern811')[field]).to eq ['vern811a vern811d vern811f vern811g vern811h vern811j vern811k vern811l vern811m vern811n vern811o vern811p vern811r vern811s vern811t vern811v vern811x']

      expect(select_by_id('vern830')[field]).to eq ['vern830a vern830d vern830f vern830g vern830h vern830j vern830k vern830l vern830m vern830n vern830o vern830p vern830r vern830s vern830t vern830v vern830x']
    end
  end
  describe 'series_exact_search' do
    let(:field) { 'series_exact_search' }
    let(:fixture_name) { 'seriesTests.mrc' }
    it do
      # Made up test, there are no legacy tests
      expect(select_by_id('1964873')[field]).to eq ['Lecture notes in computer science ;']
    end
  end
end
